"""Inspect exact LVIS target category counts before selecting training images."""
import zipfile, json
from pathlib import Path
from collections import Counter

ROOT=Path('D:/AIU5-YOLO训练资料/公开数据/cache')
MAPPING={'cup':0,'mug':0,'knife':1,'bowl':2,'bed':3,'book':4,'scissors':5,'bird':6,'dog':7,'apple':8,'carrot':9,'sword':10,'ax':11,'bow_(weapon)':13,'armor':14,'helmet':15,'boot':17}
if __name__=='__main__':
    for split in ('val','train'):
        z=ROOT/f'lvis_v1_{split}.json.zip'
        if not z.exists(): continue
        with zipfile.ZipFile(z) as archive:
            data=json.loads(archive.read(f'lvis_v1_{split}.json'))
        categories={c['id']:c for c in data['categories']}
        counts=Counter(a['category_id'] for a in data['annotations'])
        print(split,[(c['id'],c['name'],counts[c['id']]) for c in categories.values() if any(word in c['name'] for word in ('armor','sword','axe','bow','helm','boot','greav','pickax'))],flush=True)
        print('mapped',[(c['id'],c['name'],MAPPING[c['name']],counts[c['id']]) for c in categories.values() if c['name'] in MAPPING],flush=True)
        (ROOT/f'lvis_{split}_category_counts.json').write_text(json.dumps([dict(c,instances=counts[c['id']]) for c in categories.values()],indent=2),encoding='utf-8')
        del data
