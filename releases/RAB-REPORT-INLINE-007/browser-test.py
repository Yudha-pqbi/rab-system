import asyncio, json, os
from pathlib import Path
from playwright.async_api import async_playwright

OUT=Path(os.environ.get("RAB_REPORT_TEST_OUTPUT","rab-report-inline-test"))
OUT.mkdir(parents=True,exist_ok=True)

async def main():
    checks=[]; errors=[]
    def ok(name,cond,detail=None):
        if not cond:
            raise AssertionError(f"{name}: {detail}")
        checks.append({"test":name,"status":"PASS","detail":detail})

    async with async_playwright() as p:
        browser=await p.chromium.launch(executable_path=os.environ.get("CHROMIUM_EXECUTABLE","/usr/bin/google-chrome"),args=["--no-sandbox"])
        page=await browser.new_page()
        page.on("pageerror",lambda e: errors.append(str(e)))
        await page.goto("http://127.0.0.1:8000/report.html",wait_until="domcontentloaded")
        await page.wait_for_function("document.getElementById('dbStatus').textContent.includes('Connected')",timeout=20000)
        status=await page.locator("#dbStatus").inner_text()
        ok("all active RAB loaded","129 RAB" in status,status)
        ok("all active RAB have numeric Project ID","129 Project ID" in status,status)

        await page.select_option("#clientFilter",label="PT Osid Management Corp")
        await page.evaluate("onClientChange()")
        await page.select_option("#pnlYear","2026")
        await page.select_option("#pnlPeriodType","month")
        await page.evaluate("updatePnlPeriodOptions()")

        bounds=await page.evaluate("""() => {
          const p=projectsData.find(x=>x.client_name==='PT Osid Management Corp');
          return {code:p?.canonical_project_code,b:projectReportBounds(p),plan:projectPlan(p)};
        }""")
        ok("OSID numeric Project ID is 1052",bounds["code"]=="1052",bounds)
        ok("OSID report starts September",bounds["b"]["start"]=="2026-09-01",bounds)
        ok("OSID report ends December",bounds["b"]["end"]=="2026-12-31",bounds)

        async def month_value(m):
            await page.select_option("#pnlPeriodValue",str(m))
            await page.evaluate("renderReport()")
            return await page.evaluate("""() => ({
              revenue:Number(String(document.getElementById('pnlRevenueKpi').textContent).replace(/[^0-9-]/g,'')),
              cogs:Number(String(document.getElementById('pnlCogsKpi').textContent).replace(/[^0-9-]/g,''))
            })""")
        aug=await month_value(8)
        sep=await month_value(9)
        dec=await month_value(12)
        ok("OSID August excluded from RAB Report period schedule",aug["revenue"]==0 and aug["cogs"]==0,aug)
        ok("OSID September included",abs(sep["revenue"]-10516130)<=2 and abs(sep["cogs"]-9737158)<=2,sep)
        ok("OSID December included",abs(dec["revenue"]-10516130)<=2 and abs(dec["cogs"]-9737158)<=2,dec)

        code_map=await page.evaluate("""async()=>await getOfficialProjectCodeMap(currentReport.projects)""")
        source_id=await page.evaluate("""()=>currentReport.projects[0].project_id""")
        ok("RAB Report export uses numeric Project ID",code_map.get(source_id)=="1052",{"source":source_id,"map":code_map})

        await page.select_option("#clientFilter",label="ADM Animal Nutrition Indonesia")
        await page.evaluate("onClientChange()")
        counts=await page.evaluate("""()=>({all:currentReport.projects.length,current:currentReport.financialProjects.length,
          historical:currentReport.projects.filter(p=>['HISTORICAL_REFERENCE','SUPERSEDED'].includes(String(projectPlan(p)?.plan_status||''))).length})""")
        ok("historical/superseded RAB remains represented but not double-counted",counts["historical"]>=1 and counts["current"]==counts["all"]-counts["historical"],counts)
        ok("no runtime errors",not errors,errors)
        await browser.close()

    out={"tracking":"RAB-REPORT-INLINE-007","checks":checks,"errors":errors,"passed":len(checks)}
    (OUT/"browser-results.json").write_text(json.dumps(out,indent=2),encoding="utf-8")
    print(json.dumps(out,indent=2))

asyncio.run(main())
