"""Select LVIS photos, preserve official splits, and convert target boxes to 18 fixed IDs."""
from pathlib import Path
from collections import defaultdict, Counter
from concurrent.futures import ThreadPoolExecutor
import json, zipfile, random, requests, hashlib, time
from PIL import Image, ImageDraw
from lvis_inventory import MAPPING

ROOT=Path('D:/AIU5-YOLO训练资料/公开数据')
DATA=ROOT/'dataset-v1'
CACHE=ROOT/'cache'
def select(split, budget):
    with zipfile.ZipFile(CACHE/f'lvis_v1_{split}.json.zip') as z:
        data=json.loads(z.read(f'lvis_v1_{split}.json'))
    category_map={c['id']:MAPPING[c['name']] for c in data['categories'] if c['name'] in MAPPING}
    images={r['id']:r for r in data['images']}
    boxes=defaultdict(list)
    candidates=defaultdict(set)
    for ann in data['annotations']:
        cid=ann['category_id']
        if cid not in category_map: continue
        iid=ann['image_id']; im=images[iid]
        if cid in im.get('not_exhaustive_category_ids',[]): continue
        x,y,w,h=ann['bbox']
        x2=min(im['width'],x+w); y2=min(im['height'],y+h)
        x=max(0,x); y=max(0,y); w=x2-x; h=y2-y
        if w<4 or h<4: continue
        target=category_map[cid]
        boxes[iid].append([target,(x+w/2)/im['width'],(y+h/2)/im['height'],w/im['width'],h/im['height']])
        candidates[target].add(iid)
    # Never retain an image with a known non-exhaustive annotation for any requested class.
    bad={iid for iid in boxes if set(images[iid].get('not_exhaustive_category_ids',[])) & set(category_map)}
    selected=set(); rng=random.Random(20261011)
    for cid in sorted(candidates,key=lambda c:len(candidates[c])):
        ids=sorted(candidates[cid]-bad); rng.shuffle(ids)
        already=sum(i in selected for i in ids)
        selected.update([i for i in ids if i not in selected][:max(0,budget-already)])
    rows=[]
    for iid in sorted(selected):
        im=images[iid]
        # LVIS train/val can both refer to COCO train2017; retain their original explicit URL.
        rows.append({'key':f'coco_{iid:012d}','split':split,'source':'LVIS-v1','source_image_id':iid,'url':im['coco_url'].replace('http:','https:'),'width':im['width'],'height':im['height'],'license':im.get('license','COCO per-image license; see original source'),'source_page':im.get('flickr_url',im['coco_url']),'labels':boxes[iid],'annotation_status':'official LVIS boxes; known non-exhaustive target images excluded','group':f'coco_{iid:012d}'})
    print(split,'selected',len(rows),'instances',dict(Counter(b[0] for r in rows for b in r['labels'])),flush=True)
    del data,images,boxes
    return rows

def download(row):
    path=DATA/'images'/row['split']/(row['key']+'.jpg')
    label=DATA/'labels'/row['split']/(row['key']+'.txt')
    path.parent.mkdir(parents=True,exist_ok=True); label.parent.mkdir(parents=True,exist_ok=True)
    try:
        if not path.exists():
            for attempt in range(3):
                try:
                    url=row['url'].replace('https://images.cocodataset.org/','https://s3.amazonaws.com/images.cocodataset.org/')
                    resp=requests.get(url,timeout=(15,50)); resp.raise_for_status()
                    temp=path.with_suffix('.part'); temp.write_bytes(resp.content)
                    with Image.open(temp) as im: im.verify()
                    temp.replace(path)
                    break
                except Exception:
                    if attempt==2: raise
                    time.sleep(1+attempt)
        with Image.open(path) as im:
            if im.size!=(row['width'],row['height']): raise ValueError('image dimensions mismatch')
        label.write_text('\n'.join(str(b[0])+' '+' '.join(f'{v:.7f}' for v in b[1:]) for b in row['labels'])+'\n',encoding='utf-8')
        row['sha256']=hashlib.sha256(path.read_bytes()).hexdigest()
        return row
    except Exception as e:
        print('FAILED',row['key'],str(e),flush=True)
        return None

def sheets(rows):
    out=ROOT/'lvis-review'; out.mkdir(exist_ok=True)
    for cid in (10,11,13,14,15,17):
        picked=[r for r in rows if any(b[0]==cid for b in r['labels'])][:30]
        if not picked: continue
        sheet=Image.new('RGB',(1500,((len(picked)+5)//6)*200),'#dddddd'); d=ImageDraw.Draw(sheet)
        for i,row in enumerate(picked):
            im=Image.open(DATA/'images'/row['split']/(row['key']+'.jpg')).convert('RGB'); w,h=im.size
            draw=ImageDraw.Draw(im)
            for cls,x,y,bw,bh in row['labels']:
                if cls==cid: draw.rectangle(((x-bw/2)*w,(y-bh/2)*h,(x+bw/2)*w,(y+bh/2)*h),outline='red',width=4)
            im.thumbnail((246,176)); x=(i%6)*250;y=(i//6)*200
            sheet.paste(im,(x+(250-im.width)//2,y));d.text((x+3,y+178),row['key'][-6:]+' '+row['split'],fill='black')
        sheet.save(out/f'class_{cid}.jpg')

if __name__=='__main__':
    DATA.mkdir(parents=True,exist_ok=True)
    selection=ROOT/'selection.json'
    rows=json.loads(selection.read_text(encoding='utf-8')) if selection.exists() else select('train',180)+select('val',40)
    assert len({r['key'] for r in rows})==len(rows),'official split overlap'
    (ROOT/'selection.json').write_text(json.dumps(rows,ensure_ascii=False),encoding='utf-8')
    valid=[]
    with ThreadPoolExecutor(max_workers=10) as pool:
        for i,row in enumerate(pool.map(download,rows),1):
            if row: valid.append(row)
            if i%100==0: print('images',i,'/',len(rows),'successful',len(valid),flush=True)
    (DATA/'manifest.json').write_text(json.dumps(valid,ensure_ascii=False,indent=2),encoding='utf-8')
    sheets(valid)
    print('LVIS COMPLETE',len(valid),flush=True)
