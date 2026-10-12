"""Read the supplied metadata database without modifying it; consolidate source leads and class mappings."""
from pathlib import Path
from collections import Counter
from urllib.parse import urlsplit, urlunsplit
import csv, hashlib, json, sqlite3

CLASS_MAP = {'helmet': 15, 'armor': 14, 'greaves': 16, 'boots': 17}
NAMES = {14: 'armor', 15: 'helmet', 16: 'leggings', 17: 'boots'}

def canonical(url):
    parts = urlsplit(url.strip())
    return urlunsplit((parts.scheme.lower(), parts.netloc.lower(), parts.path.rstrip('/'), '', ''))

def audit(source, output):
    source, output = Path(source), Path(output)
    output.mkdir(parents=True, exist_ok=True)
    leads, files, invalid = {}, [], []
    for path in sorted(source.rglob('*.json')):
        data = json.loads(path.read_text(encoding='utf-8-sig'))
        valid = [r for r in data if isinstance(r, dict) and r.get('category') in CLASS_MAP and r.get('page_url')] if isinstance(data, list) else []
        files.append({'path': str(path.relative_to(source)), 'entries': len(data), 'valid_resource_rows': len(valid), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
        invalid.extend({'file': str(path.relative_to(source)), 'row': r} for r in data if r not in valid)
        for row in valid:
            url = canonical(row['page_url'])
            lead = leads.setdefault(url, {'page_url': url, 'name': row.get('name_cn') or row.get('name_en'), 'source_site': row.get('source_site', ''), 'expected_classes': [], 'origins': [], 'image_urls': [], 'claimed_licenses': [], 'status': 'metadata_only_not_training_ready'})
            for field, value in [('expected_classes', CLASS_MAP[row['category']]), ('origins', str(path.relative_to(source))), ('image_urls', row.get('image_url', '')), ('claimed_licenses', row.get('license', ''))]:
                if value and value not in lead[field]: lead[field].append(value)
    db_path = source/'toy_armor_3d.db'
    connection = sqlite3.connect(db_path.as_uri()+'?mode=ro&immutable=1', uri=True)
    db = {'sha256': hashlib.sha256(db_path.read_bytes()).hexdigest(), 'read_mode': 'ro+immutable', 'counts': {t: connection.execute('SELECT count(*) FROM '+t).fetchone()[0] for t in ('models', 'dataset_images', 'yolo_labels')}, 'image_status': dict(connection.execute('SELECT status,count(*) FROM dataset_images GROUP BY status'))}
    connection.close()
    pictures = [p for p in source.rglob('*') if p.suffix.lower() in {'.jpg','.jpeg','.png','.webp','.bmp'}]
    labels = [p for p in (source/'yolo').rglob('*.txt') if p.name != 'classes.txt']
    result = {'source': str(source), 'source_unchanged': True, 'files': files, 'resource_rows': sum(f['valid_resource_rows'] for f in files), 'unique_pages': len(leads), 'extra_root_json_rows': sum(f['valid_resource_rows'] for f in files if '/' not in f['path'].replace('\\','/')), 'image_files': len(pictures), 'label_files': len(labels), 'sqlite': db, 'class_mapping': [{'source': k, 'final_id': v, 'final_name': NAMES[v]} for k,v in CLASS_MAP.items()], 'candidate_counts': dict(Counter(NAMES[cid] for r in leads.values() for cid in r['expected_classes'])), 'skipped_non_resource_rows': len(invalid), 'ready_for_training': False, 'reasons': ['No actual image or bounding-box annotation files supplied.', 'Database license and URL flags are claims until checked against the original source.', 'A whole figurine is not a torso armor bounding box.', 'Bootstrap full-frame guessed labels are excluded.']}
    (output/'数据库检查.json').write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
    (output/'资源线索.json').write_text(json.dumps(list(leads.values()), ensure_ascii=False, indent=2), encoding='utf-8')
    with (output/'资源线索.csv').open('w', newline='', encoding='utf-8-sig') as f:
        writer = csv.DictWriter(f, fieldnames=['name','source_site','page_url','classes','image_urls','claimed_licenses','origins','status']); writer.writeheader()
        for row in leads.values(): writer.writerow({**{k: row[k] for k in ('name','source_site','page_url','status')}, 'classes': '|'.join(NAMES[c] for c in row['expected_classes']), **{k: '|'.join(row[k]) for k in ('image_urls','claimed_licenses','origins')}})
    return result

if __name__ == '__main__':
    import argparse
    p=argparse.ArgumentParser();p.add_argument('source');p.add_argument('output');a=p.parse_args()
    print(json.dumps(audit(a.source,a.output),ensure_ascii=False,indent=2))
