"""Probe public source APIs and preview URLs; record evidence and never execute incoming scripts."""
from pathlib import Path
import hashlib, json, time, urllib.request, urllib.error

UA='AIU5DatasetResearch/1.0 (local educational prototype)'

def fetch(url):
    request=urllib.request.Request(url,headers={'User-Agent':UA})
    with urllib.request.urlopen(request,timeout=25) as response:
        return response.read(16*1024*1024),response.headers.get('Content-Type',''),response.status,response.url

def probe(output, leads):
    output=Path(output);output.mkdir(parents=True,exist_ok=True)
    tasks=[]
    for row in json.loads(Path(leads).read_text(encoding='utf-8')):
        for url in row['image_urls']:
            tasks.append({'url': url, 'kind': 'provided_preview', 'page_url': row['page_url'], 'license_claim': row['claimed_licenses']})
        if row['source_site']=='sketchfab' and row['image_urls']:
            uid=row['page_url'].rsplit('-',1)[-1]
            tasks.append({'url':'https://api.sketchfab.com/v3/models/'+uid,'kind':'source_metadata','page_url':row['page_url']})
    for item in tasks:
        try:
            raw,ctype,status,final=fetch(item['url']);item.update(http_status=status,content_type=ctype,bytes=len(raw),final_url=final)
            key=hashlib.sha256(item['url'].encode()).hexdigest()[:16]
            if ctype.startswith('image/'):
                from PIL import Image
                from io import BytesIO
                with Image.open(BytesIO(raw)) as image:
                    item['size']=list(image.size)
                    image.convert('RGB').save(output/(key+'.jpg'),quality=95)
                item['local_image']=key+'.jpg';item['status']='downloaded_quarantine_license_and_boxes_pending'
            elif 'json' in ctype:
                value=json.loads(raw);(output/(key+'.json')).write_text(json.dumps(value,ensure_ascii=False,indent=2),encoding='utf-8')
                item['license']=value.get('license');item['thumbnails']=value.get('thumbnails');item['status']='source_metadata_received'
            else:item['status']='not_an_image'
        except Exception as error:item['status']='fetch_failed';item['error']=str(error)
        print(json.dumps(item,ensure_ascii=False),flush=True)
        time.sleep(.3)
    (output/'来源核验.json').write_text(json.dumps(tasks,ensure_ascii=False,indent=2),encoding='utf-8')

if __name__=='__main__':
    import argparse
    parser=argparse.ArgumentParser();parser.add_argument('leads');parser.add_argument('output');args=parser.parse_args();probe(args.output,args.leads)
