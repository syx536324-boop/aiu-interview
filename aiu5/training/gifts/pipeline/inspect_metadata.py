"""Summarize source categories and build reviewable Wikimedia candidate sheets."""
from pathlib import Path
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
import json, requests, hashlib, re
from PIL import Image, ImageOps, ImageDraw

ROOT = Path('D:/AIU5-YOLO训练资料/公开数据')
CACHE = ROOT / 'cache'
COMMONS = ROOT / 'commons-review'
COMMONS.mkdir(parents=True, exist_ok=True)
def extra_category(cat, name):
    target = CACHE / (name+'.json')
    if not target.exists():
        r = requests.get('https://commons.wikimedia.org/w/api.php', params={'action':'query','generator':'categorymembers','gcmtitle':'Category:'+cat,'gcmtype':'file','gcmlimit':100,'prop':'imageinfo','iiprop':'url|extmetadata','iiurlwidth':960,'format':'json'},timeout=40, headers={'User-Agent':'AIU5DatasetResearch/1.0 (local educational prototype)'})
        if r.status_code != 200:
            print('Optional category unavailable',cat,r.status_code,flush=True)
            return
        target.write_text(r.text,encoding='utf-8')

def get_image(row):
    target = COMMONS / row['file']
    try:
        if not target.exists():
            r=requests.get(row['url'],timeout=40,headers={'User-Agent':'AIU5DatasetResearch/1.0'})
            r.raise_for_status()
            target.write_bytes(r.content)
        with Image.open(target) as im:
            im.verify()
        return row
    except Exception as e:
        print('image failed',row['index'],str(e),flush=True)

if __name__=='__main__':
    extra_category('Greaves','commons_greaves_general')
    extra_category('Pickaxes in museums','commons_pickaxes_museum')
    rows=[]
    seen=set()
    for f in sorted(CACHE.glob('commons*.json')):
        data=json.loads(f.read_text(encoding='utf-8'))
        for page in data.get('query',{}).get('pages',{}).values():
            if page['pageid'] in seen: continue
            seen.add(page['pageid'])
            info=page.get('imageinfo',[{}])[0]
            meta=info.get('extmetadata',{})
            license=meta.get('LicenseShortName',{}).get('value','')
            if not any(s in license.lower() for s in ('cc0','cc-zero','public domain','cc by','cc-by','pd-')): continue
            # Only photos; drawings, diagrams and videos excluded during the following review.
            if not info.get('url','').split('?')[0].lower().endswith(('.jpg','.jpeg','.png')): continue
            index=len(rows)
            rows.append({'index':index,'file':f'{index:03d}_{page["pageid"]}.jpg','title':page['title'], 'class_id':12 if 'pickax' in f.name else 16,'url':info.get('thumburl',info['url']),'original_url':info['url'],'source_page':info.get('descriptionurl'),'license':license,'metadata':meta})
    with ThreadPoolExecutor(max_workers=5) as pool:
        valid=[r for r in pool.map(get_image, rows) if r]
    (COMMONS/'candidates.json').write_text(json.dumps(valid,ensure_ascii=False,indent=2),encoding='utf-8')
    for start in range(0,len(valid),30):
        group=valid[start:start+30]
        sheet=Image.new('RGB',(1200, int((len(group)+5)//6)*190),'#dddddd')
        draw=ImageDraw.Draw(sheet)
        for i,row in enumerate(group):
            im=Image.open(COMMONS/row['file']).convert('RGB')
            im.thumbnail((194,162))
            x=(i%6)*200; y=(i//6)*190
            sheet.paste(im,(x+(200-im.width)//2,y))
            draw.text((x+4,y+164),str(row['index'])+' / '+str(row['class_id']),fill='black')
        sheet.save(COMMONS/f'sheet_{start:03d}.jpg')
    print('COMMONS',len(valid),dict(Counter(r['class_id'] for r in valid)),flush=True)
    for row in valid: print(row['index'],ascii(row['title']),flush=True)
    c=json.loads((CACHE/'cleveland_greaves.json').read_text(encoding='utf-8'))
    print('CLEVELAND', [(r['id'],r['title'],r.get('share_license_status')) for r in c.get('data',[])],flush=True)
