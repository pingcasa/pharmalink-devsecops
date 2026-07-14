import json, os, argparse, datetime

def load_trivy(path):
    with open(path) as f:
        data = json.load(f)
    vulns = []
    for result in data.get('Results', []):
        for v in result.get('Vulnerabilities', []) or []:
            vulns.append({
                'id':       v.get('VulnerabilityID', 'N/A'),
                'severity': v.get('Severity', 'UNKNOWN').upper(),
                'package':  v.get('PkgName', 'N/A'),
                'version':  v.get('InstalledVersion', 'N/A'),
                'fixed_in': v.get('FixedVersion', 'N/A'),
                'source':   'Trivy'
            })
    return vulns

def load_grype(path):
    with open(path) as f:
        data = json.load(f)
    vulns = []
    for m in data.get('matches', []):
        fix_versions = m.get('vulnerability', {}).get('fix', {}).get('versions', [])
        vulns.append({
            'id':       m.get('vulnerability', {}).get('id', 'N/A'),
            'severity': m.get('vulnerability', {}).get('severity', 'UNKNOWN').upper(),
            'package':  m.get('artifact', {}).get('name', 'N/A'),
            'version':  m.get('artifact', {}).get('version', 'N/A'),
            'fixed_in': fix_versions[0] if fix_versions else 'N/A',
            'source':   'Grype'
        })
    return vulns

def deduplicate(vulns):
    seen, result = set(), []
    for v in vulns:
        key = f"{v['id']}-{v['package']}"
        if key not in seen:
            seen.add(key)
            result.append(v)
    return result

def generate_report(args):
    trivy = load_trivy(args.trivy)
    grype = load_grype(args.grype)
    all_v = deduplicate(trivy + grype)

    critical = [v for v in all_v if v['severity'] == 'CRITICAL']
    high     = [v for v in all_v if v['severity'] == 'HIGH']
    medium   = [v for v in all_v if v['severity'] == 'MEDIUM']
    low      = [v for v in all_v if v['severity'] == 'LOW']

    if len(critical) > 0:
        decision = 'REJECT'
    elif len(high) > 5:
        decision = 'REVIEW'
    else:
        decision = 'APPROVE'

    report = {
        'image':      args.image,
        'partner':    args.partner,
        'scan_date':  datetime.datetime.utcnow().isoformat() + 'Z',
        'scan_tools': ['Trivy', 'Grype'],
        'summary': {
            'total':    len(all_v),
            'critical': len(critical),
            'high':     len(high),
            'medium':   len(medium),
            'low':      len(low)
        },
        'decision': decision,
        'vulnerabilities': all_v
    }

    os.makedirs('reports', exist_ok=True)
    with open('reports/scan-report.json', 'w') as f:
        json.dump(report, f, indent=2, ensure_ascii=False)

    print(f"\n{'='*50}")
    print(f"Image    : {args.image}")
    print(f"Partner  : {args.partner}")
    print(f"Decision : {decision}")
    print(f"CRITICAL : {len(critical)}")
    print(f"HIGH     : {len(high)}")
    print(f"MEDIUM   : {len(medium)}")
    print(f"{'='*50}\n")

    if decision == 'REJECT':
        print("CVE CRITICAL détectés :")
        for v in critical:
            print(f"  - {v['id']} | {v['package']}:{v['version']} | [{v['source']}]")

if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('--trivy',   required=True)
    p.add_argument('--grype',   required=True)
    p.add_argument('--image',   required=True)
    p.add_argument('--partner', required=True)
    generate_report(p.parse_args())