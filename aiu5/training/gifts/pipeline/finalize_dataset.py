"""Merge complete COCO boxes and curated equipment labels with explicit per-image provenance."""
from pathlib import Path
from collections import defaultdict, Counter
import json, zipfile, csv, hashlib, math
from dataset_check import validate

ROOT=Path('D:/AIU5-YOLO训练资料/公开数据');DATA=ROOT/'dataset-v1'
COCO_MAP={47:0,49:1,51:2,65:3,84:4,87:5,16:6,18:7,53:8,57:9}
def coco_metadata(wanted):
    images={};boxes=defaultdict(list);crowds=set()
    with zipfile.ZipFile(ROOT/'cache/annotations_trainval2017.zip') as z:
        for split in ('train','val'):
            data=json.loads(z.read(f'annotations/instances_{split}2017.json'))
            licenses={r['id']:r for r in data['licenses']}
            for r in data['images']:
                if r['id'] in wanted:images[r['id']]=dict(r,license_detail=licenses[r['license']])
            for a in data['annotations']:
                if a['image_id'] not in wanted or a['category_id'] not in COCO_MAP:continue
                if a.get('iscrowd'):crowds.add(a['image_id']);continue
                im=images[a['image_id']];x,y,w,h=a['bbox'];x2=min(im['width'],x+w);y2=min(im['height'],y+h);x=max(0,x);y=max(0,y);w=x2-x;h=y2-y
                if w<2 or h<2:continue
                boxes[a['image_id']].append([COCO_MAP[a['category_id']],(x+w/2)/im['width'],(y+h/2)/im['height'],w/im['width'],h/im['height']])
            del data
    return images,boxes,crowds

def main():
    lvis=json.loads((DATA/'manifest.json').read_text(encoding='utf-8'))
    images,boxes,crowds=coco_metadata({r['source_image_id'] for r in lvis})
    curated=json.loads((ROOT/'lvis-curation.json').read_text(encoding='utf-8'))
    accepted=set(curated['accepted_image_ids']);reject=Counter();rows=[]
    for r in lvis:
        iid=r['source_image_id'];im=images[iid]
        if im['license'] not in (4,5,8):reject['license not CC-BY / CC-BY-SA / US-government']+=1;continue
        if iid in crowds:reject['target crowd annotation']+=1;continue
        rare=[b for b in r['labels'] if b[0] in (10,11,13,14)]
        if rare and iid not in accepted:reject['rare equipment not visually accepted']+=1;continue
        r['labels']=boxes[iid]+[b for b in r['labels'] if b[0]>=10]
        if not r['labels']:reject['no complete target box']+=1;continue
        r['license']=im['license_detail'];r['source_page']=im.get('flickr_url',im['coco_url']);r['annotation_status']='COCO2017 complete selected daily-object boxes + LVIS-v1 equipment boxes; rare equipment visually filtered'
        for group in curated.get('known_same_scene_groups',[]):
            if iid in group:r['group']='coco_scene_'+str(group[0])
        rows.append(r)
    for name in ('commons-manifest.json','museum-manifest.json'):
        if (DATA/name).exists():rows+=json.loads((DATA/name).read_text(encoding='utf-8'))
    # Remove only exact stale image/label files in this generated dataset (never touch source cache).
    keep={(r['split'],r['key']) for r in rows}
    for kind,suffix in (('images','.jpg'),('labels','.txt')):
        for p in (DATA/kind).glob('*/*'+suffix):
            if (p.parent.name,p.stem) not in keep:p.unlink()
    for r in rows:
        p=DATA/'labels'/r['split']/(r['key']+'.txt')
        p.write_text('\n'.join(str(b[0])+' '+' '.join(f'{v:.7f}' for v in b[1:]) for b in r['labels'])+'\n',encoding='utf-8')
    (DATA/'manifest-final.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf-8')
    catalog=json.loads(Path('D:/aiu5/training/gifts/catalog.json').read_text(encoding='utf-8'));names={r['class_id']:r['class_name'] for r in catalog['classes']}
    import yaml
    rare_images=Counter(cid for r in rows if r['split']=='train' for cid in {b[0] for b in r['labels'] if b[0] in (10,11,12,13,14,16)})
    training=[]
    for r in rows:
        if r['split']!='train':continue
        factor=max([1]+[min(10,math.ceil(80/rare_images[cid])) for cid in {b[0] for b in r['labels']} if cid in rare_images])
        training.extend([(DATA/'images/train'/(r['key']+'.jpg')).as_posix()]*factor)
    (DATA/'train-balanced.txt').write_text('\n'.join(training)+'\n',encoding='utf-8')
    (DATA/'data.yaml').write_text(yaml.safe_dump({'path':DATA.as_posix(),'train':'train-balanced.txt','val':'images/val','test':'images/test','names':names},allow_unicode=True,sort_keys=False),encoding='utf-8')
    report=validate(DATA,names);report['rejected_lvis_images']=dict(reject);report['effective_training_samples_per_epoch']=len(training);report['sampling']='Rare equipment paths are repeated up to 10 times; repeated paths are NOT additional unique photos.'
    (DATA/'dataset-summary.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    with (ROOT/'类别样本数量.csv').open('w',encoding='utf-8-sig',newline='') as f:
        writer=csv.writer(f);writer.writerow(['ID','英文','中文','训练实例','验证实例','测试实例'])
        for c in catalog['classes']:writer.writerow([c['class_id'],c['class_name'],c['name_zh']]+[report['instances'][s][c['class_name']] for s in ('train','val','test')])
    print(json.dumps(report,ensure_ascii=False,indent=2),flush=True)
if __name__=='__main__':main()
