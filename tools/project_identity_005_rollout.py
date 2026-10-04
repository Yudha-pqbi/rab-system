"""PROJECT-IDENTITY-005: validate and commit a local adapter on a release branch.
Reads public numeric project metadata only. Does not merge main or change money.
Run exclusively by the explicitly scoped GitHub Actions release workflow.
"""
import base64
import hashlib
import json
import os
import pathlib
import re
import subprocess
import urllib.request
import yaml

repo = os.environ['GITHUB_REPOSITORY']
head = os.environ['GITHUB_SHA']
branch = 'release/project-identity-005-20261004'
assert repo in ['Yudha-pqbi/general-ledger-system', 'Yudha-pqbi/payvance-system', 'Yudha-pqbi/invoice-system']
assert os.environ['GITHUB_REF'] == 'refs/heads/' + branch
root = 'https://api.github.com/repos/' + repo

def api(path, body=None, method=None):
    request = urllib.request.Request(root + path,
        data=None if body is None else json.dumps(body).encode(),
        headers={'Authorization': 'Bearer ' + os.environ['GH_TOKEN'], 'Accept': 'application/vnd.github+json', 'Content-Type': 'application/json'},
        method=method or ('GET' if body is None else 'POST'))
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)

def read(path, ref):
    return base64.b64decode(api('/contents/' + path + '?ref=' + ref)['content']).decode()

def public_read(path, ref):
    with urllib.request.urlopen('https://raw.githubusercontent.com/Yudha-pqbi/rab-system/' + ref + '/' + path, timeout=30) as response:
        return response.read().decode()

base = api('/git/ref/heads/main')['object']['sha']
module = public_read('project-identity.js', '2644063b8ff3fad6f91921d4fa72628b7a0ce850')
b = module.encode()
assert hashlib.sha1(b'blob ' + str(len(b)).encode() + b'\0' + b).hexdigest() == '0029190eb9ae13cd8e07b96507131b992bfd9cd3'
rab = public_read('index.html', '14c7c1fe895fbb3512477d52adaa18d0a7b82669')
public_key = re.search(r'sb_publishable_[A-Za-z0-9_-]+', rab).group()
public_url = 'https://rljqyaycshwpoteoxgem.supabase.co'
assert public_url in rab
# Read-only metadata, using publishable apikey correctly (not as a user JWT).
req = urllib.request.Request(public_url + '/rest/v1/rpc/project_identity_dictionary_v1', data=b'{}', headers={'apikey': public_key, 'Content-Type': 'application/json'}, method='POST')
with urllib.request.urlopen(req, timeout=20) as response:
    dictionary = json.load(response)
assert dictionary['version'] == 'PROJECT-IDENTITY-005'
assert dictionary['references']['PRJ-26092802'] == '1050' and dictionary['references']['PRJ-01322001'] == '1002'
assert dictionary['ambiguous_reference_count'] == 0

paths = ['index.html'] + (['project-profitability.html'] if repo.endswith('/general-ledger-system') else [])
hashes = {}
inline_hashes = {}
for path in paths:
    raw = read(path, base)
    assert read(path, head) == raw, 'Release runtime already differs from main; explicit reconciliation required'
    assert 'project-identity.js' not in raw and public_url in raw
    config = '<script>window.__PROJECT_IDENTITY_PUBLIC_CONFIG=Object.freeze(' + json.dumps({'url': public_url, 'key': public_key}) + ');</script>\n'
    tag = config + '<script src="project-identity.js?v=20261004-005"></script>\n'
    pos = raw.lower().rfind('</body>')
    assert pos >= 0
    edited = raw[:pos] + tag + raw[pos:]
    assert edited.replace(tag, '', 1) == raw
    old = re.findall(r'<script(?:\s[^>]*)?>([\s\S]*?)</script>', raw, re.I)
    new = re.findall(r'<script(?:\s[^>]*)?>([\s\S]*?)</script>', edited, re.I)
    assert [s for s in old if s.strip()] == [s for s in new if s.strip() and not s.startswith('window.__PROJECT_IDENTITY_PUBLIC_CONFIG=')]
    inline_hashes[path] = hashlib.sha256('\n'.join(old).encode()).hexdigest()
    pathlib.Path(path).write_text(edited)
    hashes[path] = hashlib.sha256(edited.encode()).hexdigest()
    for i, script in enumerate(new):
        if script.strip():
            check = pathlib.Path('/tmp/identity-' + path + '-' + str(i) + '.js')
            check.write_text(script)
            subprocess.run(['node', '--check', str(check)], check=True)
pathlib.Path('project-identity.js').write_text(module)
subprocess.run(['node', '--check', 'project-identity.js'], check=True)
hashes['project-identity.js'] = hashlib.sha256(module.encode()).hexdigest()
spec = yaml.safe_load(public_read('.github/workflows/project-identity-005.yml', '0861f8106b43c89d468bb1b6e92680c8d85cdccd'))
test = spec['jobs']['validate']['steps'][1]['run']
subprocess.run(['bash', '-euo', 'pipefail', '-c', test], check=True)
legacy_test = json.loads(pathlib.Path('browser-results.json').read_text())
keyline = "key=enc({'alg':'none'})+'.'+enc({'role':'anon','ref':'identitytest'})+'.test'"
assert keyline in test
subprocess.run(['bash', '-euo', 'pipefail', '-c', test.replace(keyline, "key='sb_publishable_fixture'", 1)], check=True)
publishable_test = json.loads(pathlib.Path('browser-results.json').read_text())
assert all(legacy_test['checks'].values()) and all(publishable_test['checks'].values())
results = {'legacy_anon_adapter': legacy_test, 'publishable_adapter': publishable_test,
    'real_metadata_api': {'status': 'PASS', 'http': 200, 'projects': len(dictionary['projects']), 'ambiguous_references': 0},
    'scope': 'Real shared metadata read; actual adapter with two synthetic credential modes/export libraries. No production user login, no financial write.'}
meta = {'tracking': 'PROJECT-IDENTITY-005', 'repository': repo, 'base': base, 'files': hashes,
    'existing_inline_scripts_unchanged': inline_hashes, 'public_key_modes': ['publishable', 'legacy_anon'],
    'adapter_source_commit': '2644063b8ff3fad6f91921d4fa72628b7a0ce850', 'adapter_blob': '0029190eb9ae13cd8e07b96507131b992bfd9cd3',
    'adapter_checks': legacy_test['passed'] + publishable_test['passed'],
    'scope': 'Numeric project presentation/export; existing financial logic, parser, raw source keys and write payloads unchanged. Adapter and read-only metadata configuration are bundled in this app, with no runtime dependency on another engine frontend.'}
pathlib.Path('release.json').write_text(json.dumps(meta, indent=2))
pathlib.Path('browser-results.json').write_text(json.dumps(results, indent=2))
assert api('/git/ref/heads/main')['object']['sha'] == base
assert api('/git/ref/heads/' + branch)['object']['sha'] == head
entries = []
for path, local in [(p, p) for p in hashes] + [('releases/PROJECT-IDENTITY-005/release.json', 'release.json'), ('releases/PROJECT-IDENTITY-005/browser-results.json', 'browser-results.json')]:
    blob = api('/git/blobs', {'content': pathlib.Path(local).read_text(), 'encoding': 'utf-8'})
    entries.append({'path': path, 'mode': '100644', 'type': 'blob', 'sha': blob['sha']})
tree = api('/git/trees', {'base_tree': api('/git/commits/' + head)['tree']['sha'], 'tree': entries})
commit = api('/git/commits', {'message': 'PROJECT-IDENTITY-005: tested numeric identity display and exports using publishable metadata', 'tree': tree['sha'], 'parents': [head]})
api('/git/refs/heads/' + branch, {'sha': commit['sha'], 'force': False}, 'PATCH')
print(json.dumps({'status': 'VALIDATED_BRANCH_ONLY', 'head': commit['sha'], 'manifest': meta, 'verification': results, 'files': entries}, indent=2))
