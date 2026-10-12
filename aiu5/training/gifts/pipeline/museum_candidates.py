"""Collect CC0 single-object museum photographs as reviewable rare-equipment candidates."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
from PIL import Image, ImageDraw
import json, requests, re, time

ROOT=Path('D:/AIU5-YOLO训练资料/公开数据');OUT=ROOT/'museum-review';OUT.mkdir(exist_ok=True)
QUERIES={10:('sword',r'\bsword\b'),11:('axe',r'\b(axe|ax)\b'),13:('bow',r'\bbow\b'),14:('breastplate',r'\b(breastplate|cuirass)\b')}
def query(pair):
    cid,(term,pattern)=pair; cache=OUT/f'query_{cid}.json'
    if not cache.exists():
        for attempt in range(3):
            try:
                r=requests.get('https://openaccess-api.clevelandart.org/api/artworks/',params={'q':term,'has_image':1,'limit':100},timeout=40);r.raise_for_status();cache.write_text(r.text,encoding='utf-8');break
            except requests.RequestException:
                if attempt==2: raise
                time.sleep(2)
    data=json.loads(cache.read_text(encoding='utf-8'))
    rows=[]
    for r in data.get('data',[]):
        if not re.search(pattern,r['title'],re.I) or r.get('share_license_status')!='CC0':continue
        if cid==13 and any(w in r['title'].lower() for w in ('bowl','tie','bowing','bow-shaped','bowstring')):continue
        url=r.get('images',{}).get('web',{}).get('url')
        if not url:continue
        rows.append({'key':'cleveland_'+str(r['id']),'class_id':cid,'title':r['title'],'url':url,'source_page':r['url'],'license':'CC0','metadata':r,'group':'cleveland_'+r['accession_number']})
    return rows
def download(r):
    try:
        p=OUT/(r['key']+'.jpg')
        if not p.exists():
            response=requests.get(r['url'],timeout=45);response.raise_for_status();p.write_bytes(response.content)
        with Image.open(p) as im:im.verify()
        return r
    except Exception as e:print('museum skipped',r['key'],str(e),flush=True)
if __name__=='__main__':
    rows=[]
    with ThreadPoolExecutor(max_workers=4) as pool:
        for result in pool.map(query,QUERIES.items()):rows+=result
    with ThreadPoolExecutor(max_workers=5) as pool:rows=[r for r in pool.map(download,rows) if r]
    for i,r in enumerate(rows):r['index']=i
    (OUT/'candidates.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf-8')
    for start in range(0,len(rows),24):
        group=rows[start:start+24];sheet=Image.new('RGB',(1440,((len(group)+5)//6)*210),'#dddddd');draw=ImageDraw.Draw(sheet)
        for i,r in enumerate(group):
            im=Image.open(OUT/(r['key']+'.jpg')).convert('RGB');im.thumbnail((234,184));x=(i%6)*240;y=(i//6)*210
            sheet.paste(im,(x+(240-im.width)//2,y));draw.text((x+3,y+186),f'{r["index"]} / {r["class_id"]} / {r["key"][10:]}',fill='black')
        sheet.save(OUT/f'sheet_{start:03d}.jpg')
    print('MUSEUM CANDIDATES',len(rows),[(r['index'],r['class_id'],r['key'],r['title']) for r in rows],flush=True)
