"""Collect licensed Commons toy-photo candidates and original-page evidence into a review area."""
from pathlib import Path
from urllib.parse import urlencode
from concurrent.futures import ThreadPoolExecutor
from io import BytesIO
from PIL import Image, ImageDraw
import hashlib, json, re, time
from source_research import fetch

QUERIES=['intitle:"toy sword" filetype:bitmap','intitle:"Minecraft Pickaxe" filetype:bitmap','intitle:"Lego knight" filetype:bitmap','intitle:"toy armor" filetype:bitmap','intitle:"foam sword" filetype:bitmap','intitle:"MinecraftToys" filetype:bitmap']

def search(query):
    params={'action':'query','format':'json','generator':'search','gsrsearch':query,'gsrnamespace':6,'gsrlimit':8,'prop':'imageinfo','iiprop':'url|size|extmetadata','iiurlwidth':1024}
    try:
        data=json.loads(fetch('https://commons.wikimedia.org/w/api.php?'+urlencode(params))[0])
        rows=[]
        for page in data.get('query',{}).get('pages',{}).values():
            info=page.get('imageinfo',[{}])[0]; meta=info.get('extmetadata',{});lic=meta.get('LicenseShortName',{}).get('value','')
            if not re.search(r'\.(?:jpe?g|png)$',info.get('url',''),re.I):continue
            if not (lic.startswith('CC BY') or lic in ('CC0','Public domain')):continue
            url=info.get('thumburl') or info.get('url','')
            if not re.search(r'\.(?:jpe?g|png)(?:\?|$)',url,re.I):continue
            rows.append({'key':'commons_'+str(page['pageid']),'title':page['title'],'query':query,'source_page':info['descriptionurl'],'image_url':url,'original_url':info['url'],'license':lic,'metadata':meta,'status':'candidate_not_annotated'})
        return rows
    except Exception as error:
        print('SEARCH_FAILED '+query+' '+str(error),flush=True);return []

def download(row, output):
    try:
        raw,ctype,status,final=fetch(row['image_url'])
        with Image.open(BytesIO(raw)) as im:
            row['size']=list(im.size);im.convert('RGB').save(output/(row['key']+'.jpg'),quality=95)
        row['file']=row['key']+'.jpg';row['sha256']=hashlib.sha256((output/row['file']).read_bytes()).hexdigest();row['status']='downloaded_review_pending'
    except Exception as error:row['status']='download_failed';row['error']=str(error)
    return row

def sheets(rows, output):
    rows=[r for r in rows if r.get('file')]
    for start in range(0,len(rows),20):
        part=rows[start:start+20];canvas=Image.new('RGB',(1400,((len(part)+4)//5)*245),'#ededed');d=ImageDraw.Draw(canvas)
        for i,row in enumerate(part):
            im=Image.open(output/row['file']);im.thumbnail((274,215));x=(i%5)*280;y=(i//5)*245
            canvas.paste(im,(x+(280-im.width)//2,y));d.text((x+3,y+217),str(start+i)+' '+row['key'],fill='black')
        canvas.save(output/f'review-{start:03d}.jpg')

def collect(output, source_checks):
    output=Path(output);output.mkdir(parents=True,exist_ok=True)
    with ThreadPoolExecutor(max_workers=3) as pool:lists=list(pool.map(search,QUERIES))
    unique={r['key']:r for rows in lists for r in rows}
    with ThreadPoolExecutor(max_workers=3) as pool:rows=list(pool.map(lambda r:download(r,output),unique.values()))
    # The provided Kitty Helmet has a verified CC BY 4.0 entry in the public model API.
    for path in Path(source_checks).glob('*.json'):
        try:data=json.loads(path.read_text(encoding='utf-8'))
        except Exception:continue
        if isinstance(data,dict) and data.get('uid')=='8228efdddbc240fca37107c5057932ad' and data.get('license',{}).get('slug')=='by':
            image=max(data['thumbnails']['images'],key=lambda r:r['width'])
            row={'key':'sketchfab_'+data['uid'],'title':data['name'],'source_page':data['viewerUrl'],'image_url':image['url'],'original_url':image['url'],'license':'CC BY 4.0','license_evidence':str(path.resolve()),'metadata':{'creator':data['user']['displayName'],'license_url':data['license']['url']},'domain':'3D_render','group':'sketchfab_'+data['uid']}
            rows.append(download(row,output))
    (output/'候选图片.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf-8');sheets(rows,output)
    print(json.dumps({'candidates':len(rows),'downloaded':sum(bool(r.get('file')) for r in rows)},ensure_ascii=False),flush=True)

if __name__=='__main__':
    import argparse
    p=argparse.ArgumentParser();p.add_argument('output');p.add_argument('source_checks');a=p.parse_args();collect(a.output,a.source_checks)
