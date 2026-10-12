"""Validate label geometry, class coverage, image integrity and split leakage before training."""
from pathlib import Path
from collections import Counter, defaultdict
import hashlib, json, math
from PIL import Image

def validate(root, names):
    root=Path(root);manifest=json.loads((root/'manifest-final.json').read_text(encoding='utf-8'))
    groups=defaultdict(set);hashes=defaultdict(set);counts={s:Counter() for s in ('train','val','test')};errors=[]
    for row in manifest:
        split=row['split'];groups[row['group']].add(split)
        image=root/'images'/split/(row['key']+'.jpg');label=root/'labels'/split/(row['key']+'.txt')
        try:
            with Image.open(image) as im:im.verify()
            hashes[hashlib.sha256(image.read_bytes()).hexdigest()].add(split)
            for line in label.read_text(encoding='utf-8').splitlines():
                values=list(map(float,line.split()));assert len(values)==5
                cid,x,y,w,h=values;assert cid==int(cid) and int(cid) in names
                assert all(math.isfinite(v) for v in values)
                assert w>0 and h>0 and x-w/2>=-1e-6 and y-h/2>=-1e-6 and x+w/2<=1+1e-6 and y+h/2<=1+1e-6
                counts[split][int(cid)]+=1
        except Exception as e:errors.append(row['key']+': '+str(e))
    for group,splits in groups.items():
        if len(splits)>1:errors.append('object group leakage: '+group)
    for digest,splits in hashes.items():
        if len(splits)>1:errors.append('duplicate image across splits: '+digest)
    for split in ('train','val'):
        for cid,name in names.items():
            if not counts[split][cid]:errors.append(f'{split}: missing class {cid} {name}')
    result={'ok':not errors,'images':dict(Counter(r['split'] for r in manifest)),'instances':{s:{names[cid]:counts[s][cid] for cid in names} for s in counts},'errors':errors,'limitations':['Public-image prototype; actual player camera/toy-domain performance unverified.','Rare-class validation sets are small; aggregate mAP alone is insufficient for acceptance.','Commons/museum boxes are AI-reviewed approximate annotations, not human-certified gold labels.']}
    (root/'validation-report.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
    if errors:raise ValueError('\n'.join(errors))
    return result
