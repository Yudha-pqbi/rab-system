DO $regression$

DECLARE
 v_row record; v_payload jsonb; v_result jsonb; v_results jsonb:='[]'::jsonb;
 v_test_id text; v_actual jsonb; v_expected jsonb; v_ok boolean; v_error text;
 v_role text; v_case text; v_expected_action text; v_original_count bigint;
 v_before jsonb; v_after jsonb; v_suite_started timestamptz:=clock_timestamp();
BEGIN
 SELECT jsonb_build_object(
  'projects',(select md5(string_agg(to_jsonb(p)::text,'|' order by project_id)) from public.projects p),
  'canonical',(select md5(string_agg(to_jsonb(c)::text,'|' order by project_no)) from public.canonical_projects_candidate_v1 c),
  'links',(select md5(string_agg(to_jsonb(l)::text,'|' order by id)) from public.canonical_project_rab_links_candidate_v1 l),
  'revision',(select revision from glpp.coherent_state_v53 where id)
 ) INTO v_before;
 BEGIN
 -- Exercise the same RPC with browser permissions. Each save is rolled back.
 FOR v_row IN
  SELECT p.*,c.project_code AS expected_project_code
  FROM public.projects p
  JOIN public.canonical_project_rab_links_candidate_v1 l ON l.rab_project_id=p.project_id AND l.link_status='ACTIVE'
  JOIN public.canonical_projects_candidate_v1 c ON c.project_no=l.canonical_project_no AND c.status='ACTIVE'
  WHERE p.status<>'DELETED' ORDER BY p.project_id
 LOOP
  FOREACH v_case IN ARRAY ARRAY['new','edit'] LOOP
   v_test_id:=case when v_case='new' then gen_random_uuid()::text else v_row.project_id end;
   v_payload:=to_jsonb(v_row)-'expected_project_code'||jsonb_build_object('project_id',v_test_id,'status','APPROVED');
   v_ok:=false;v_error:=null;
   BEGIN
    EXECUTE 'SET LOCAL ROLE anon';
    v_result:=public.rab_save_with_project_identity_v1(v_payload,case when v_case='edit' then v_row.project_id else null end);
    SELECT to_jsonb(p) INTO v_actual FROM public.projects p WHERE p.project_id=v_test_id;
    v_ok:=v_result->>'status'='SAVED' AND v_result->>'project_id'=v_row.expected_project_code
      AND v_actual->'details_json'=v_payload->'details_json'
      AND v_actual->'cost_project' IS NOT DISTINCT FROM v_payload->'cost_project'
      AND v_actual->'management_fee_value' IS NOT DISTINCT FROM v_payload->'management_fee_value'
      AND v_actual->'rounded_before_tax' IS NOT DISTINCT FROM v_payload->'rounded_before_tax'
      AND v_actual->'total_after_tax' IS NOT DISTINCT FROM v_payload->'total_after_tax'
      AND v_actual->'cost_manpower' IS NOT DISTINCT FROM v_payload->'cost_manpower'
      AND v_actual->'cost_machinery' IS NOT DISTINCT FROM v_payload->'cost_machinery'
      AND v_actual->'cost_chemical' IS NOT DISTINCT FROM v_payload->'cost_chemical'
      AND v_actual->'cost_consumable' IS NOT DISTINCT FROM v_payload->'cost_consumable';
    IF NOT v_ok THEN v_error:='Unexpected identity or source amount mismatch'; END IF;
    RAISE EXCEPTION USING ERRCODE='ZX001',MESSAGE='rollback test save';
   EXCEPTION WHEN SQLSTATE 'ZX001' THEN NULL;
    WHEN OTHERS THEN v_error:=SQLSTATE||': '||SQLERRM;v_ok:=false;
   END;
   v_results:=v_results||jsonb_build_array(jsonb_build_object('case',v_case,'client',v_row.client_name,'expected',v_row.expected_project_code,'pass',coalesce(v_ok,false),'error',v_error));
  END LOOP;
 END LOOP;

 -- Letter-supported client variants; both browser database roles.
 SELECT to_jsonb(p) INTO v_payload FROM public.projects p WHERE p.client_name='Djarum' AND p.status='APPROVED' ORDER BY p.project_id LIMIT 1;
 FOREACH v_role IN ARRAY ARRAY['anon','authenticated'] LOOP
  FOREACH v_case IN ARRAY ARRAY['Djarum','PT DJARUM','PT. DJARUM','DJARUM SKT WONOGIRI'] LOOP
   v_test_id:=gen_random_uuid()::text;v_ok:=false;v_error:=null;
   BEGIN
    EXECUTE format('SET LOCAL ROLE %I',v_role);
    v_result:=public.rab_save_with_project_identity_v1(v_payload||jsonb_build_object('project_id',v_test_id,'client_name',v_case,'project_title','Security','project_area','SKT WONOGIRI'),null);
    v_ok:=v_result->>'status'='SAVED' AND v_result->>'project_id'='1001';
    RAISE EXCEPTION USING ERRCODE='ZX001',MESSAGE='rollback test save';
   EXCEPTION WHEN SQLSTATE 'ZX001' THEN NULL;
    WHEN OTHERS THEN v_error:=SQLSTATE||': '||SQLERRM;v_ok:=false;
   END;
   v_results:=v_results||jsonb_build_array(jsonb_build_object('case','Wonogiri alias','client',v_case,'role',v_role,'pass',coalesce(v_ok,false),'error',v_error));
  END LOOP;
 END LOOP;

 -- An absent snapshot must not block a verified existing canonical identity.
 v_ok:=false;v_error:=null;
 BEGIN
  DELETE FROM public.rab_client_authority_snapshot_candidate_v1 WHERE normalized_match_name='DJARUM';
  EXECUTE 'SET LOCAL ROLE anon';
  v_result:=public.rab_save_with_project_identity_v1(v_payload||jsonb_build_object('project_id',gen_random_uuid()::text,'client_name','Djarum','project_title','Security','project_area','SKT WONOGIRI'),null);
  v_ok:=v_result->>'project_id'='1001';
  RAISE EXCEPTION USING ERRCODE='ZX001',MESSAGE='rollback missing snapshot fixture';
 EXCEPTION WHEN SQLSTATE 'ZX001' THEN NULL;
  WHEN OTHERS THEN v_error:=SQLSTATE||': '||SQLERRM;v_ok:=false;
 END;
 v_results:=v_results||jsonb_build_array(jsonb_build_object('case','existing identity without snapshot','pass',coalesce(v_ok,false),'error',v_error));

 -- Unknown, non-client, ambiguous authority and ambiguous project fail atomically.
 FOREACH v_case IN ARRAY ARRAY['unknown','non_client','ambiguous_authority','ambiguous_project'] LOOP
  v_test_id:=gen_random_uuid()::text;v_ok:=false;v_error:=null;
  v_expected_action:=case v_case when 'unknown' then 'CLIENT_AUTHORITY_REVIEW' when 'non_client' then 'CLIENT_NOT_ELIGIBLE' when 'ambiguous_authority' then 'CLIENT_AUTHORITY_AMBIGUOUS' else 'REVIEW_MULTI_PROJECT' end;
  BEGIN
   IF v_case='ambiguous_authority' THEN
    UPDATE public.rab_client_authority_snapshot_candidate_v1 SET authority_status='AMBIGUOUS',governed_client_count=2 WHERE normalized_match_name='DJARUM';
   ELSIF v_case='ambiguous_project' THEN
    INSERT INTO public.rab_canonical_group_decisions_candidate_v1
    SELECT (jsonb_populate_record(null::public.rab_canonical_group_decisions_candidate_v1,
      to_jsonb(d)||jsonb_build_object('decision_id','RAB-SAVE-020-TEST-'||v_test_id))).*
    FROM public.rab_canonical_group_decisions_candidate_v1 d WHERE decision_id='DJARUM-SECURITY-V1';
   END IF;
   EXECUTE 'SET LOCAL ROLE anon';
   v_result:=public.rab_save_with_project_identity_v1(v_payload||jsonb_build_object('project_id',v_test_id,'client_name',case v_case when 'unknown' then 'RAB-SAVE-020-UNKNOWN-'||v_test_id when 'non_client' then 'HEAD OFFICE' else 'Djarum' end,'project_title','Security','project_area','SKT WONOGIRI'),null);
   v_error:='Unexpectedly saved rejected case';
   RAISE EXCEPTION USING ERRCODE='ZX001',MESSAGE='rollback guard test';
  EXCEPTION WHEN SQLSTATE 'ZX001' THEN NULL;
   WHEN OTHERS THEN v_error:=SQLERRM;v_ok:=SQLSTATE='P0001' AND position('['||v_expected_action||']' in SQLERRM)>0;
  END;
  v_ok:=v_ok AND NOT EXISTS(SELECT 1 FROM public.projects p WHERE p.project_id=v_test_id);
  v_results:=v_results||jsonb_build_array(jsonb_build_object('case',v_case,'expected_action',v_expected_action,'pass',coalesce(v_ok,false),'message',v_error));
 END LOOP;

 -- Durable aliases remain after a rebuild. No other identity rows may change.
 PERFORM public.rab_client_authority_refresh_snapshot_candidate_v1();
 v_ok:=(SELECT count(*) FROM public.rab_client_authority_snapshot_candidate_v1 WHERE normalized_match_name IN ('DJARUM','PT DJARUM','DJARUM SKT WONOGIRI') AND governed_client_name='Djarum' AND authority_status='GOVERNED' AND governed_client_count=1)=3;
 v_results:=v_results||jsonb_build_array(jsonb_build_object('case','alias survives snapshot refresh','pass',v_ok));
 RAISE EXCEPTION USING ERRCODE='ZX999',MESSAGE='rollback regression metadata fixtures';
 EXCEPTION WHEN SQLSTATE 'ZX999' THEN NULL;
 END;
 SELECT jsonb_build_object(
  'projects',(select md5(string_agg(to_jsonb(p)::text,'|' order by project_id)) from public.projects p),
  'canonical',(select md5(string_agg(to_jsonb(c)::text,'|' order by project_no)) from public.canonical_projects_candidate_v1 c),
  'links',(select md5(string_agg(to_jsonb(l)::text,'|' order by id)) from public.canonical_project_rab_links_candidate_v1 l),
  'revision',(select revision from glpp.coherent_state_v53 where id)
 ) INTO v_after;
 v_results:=v_results||jsonb_build_array(jsonb_build_object('case','baseline unchanged','pass',v_before=v_after));
 PERFORM set_config('rab_diag.suite',jsonb_build_object(
  'test_count',jsonb_array_length(v_results),
  'passed',(select count(*) from jsonb_array_elements(v_results) x where x->>'pass'='true'),
  'failed',(select coalesce(jsonb_agg(x),'[]'::jsonb) from jsonb_array_elements(v_results) x where x->>'pass' is distinct from 'true'),
  'guard_results',(select jsonb_agg(x) from jsonb_array_elements(v_results) x where x ? 'expected_action'),
  'duration_ms',round(extract(epoch from clock_timestamp()-v_suite_started)*1000),
  'baseline_before',v_before,'baseline_after',v_after
 )::text,true);
END
$regression$;
SELECT current_setting('rab_diag.suite')::jsonb AS regression_validation;