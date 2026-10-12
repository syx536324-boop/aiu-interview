"""Resolve original-page licenses and previews for supplied Sketchfab/Thingiverse model leads."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
from urllib.parse import parse_qs, urlsplit
import json, re, hashlib
from source_research import fetch
from collect_photos import download, sheets

def resolve(row, output):
    site=row['source_site'];url=row['page_url'];key=url.rsplit('-',1)[-1] if site=='sketchfab' else url.rsplit(':',1)[-1]
    result={'key':site+'_'+key,'title':row['name'],'source_page':url,'expected_classes':row['expected_classes'],'status':'metadata_pending'}
    try:
        if site=='sketchfab':
            api='https://api.sketchfab.com/v3/models/'+key;raw,ctype,status,final=fetch(api);data=json.loads(raw)
            evidence=output/(result['key']+'-source.json');evidence.write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
            result['license']=data.get('license',{}).get('label','unknown');result['license_url']=data.get('license',{}).get('url','');result['creator']=data['user']['displayName'];result['domain']='3D_render'
            if data.get('license',{}).get('slug') not in {'by','by-sa','cc0'}:
                result['status']='license_not_accepted';return result
            result['image_url']=max(data['thumbnails']['images'],key=lambda i:i['width'])['url']
        else:
            raw,ctype,status,final=fetch(url);html=raw.decode('utf-8');evidence=output/(result['key']+'-source.html');evidence.write_text(html,encoding='utf-8')
            data=json.loads(re.search(r'<script[^>]*type="application/ld\+json"[^>]*>(.*?)</script>',html,re.S).group(1));work=data['mainEntityOfPage']
            result['license_url']=work.get('license','');result['license']='CC BY-SA 4.0' if '/by-sa/' in result['license_url'] else 'CC BY 4.0' if '/by/' in result['license_url'] else 'unknown';result['creator']=work.get('author',{}).get('name','');result['domain']='review_pending'
            if result['license']=='unknown':result['status']='license_not_accepted';return result
            result['image_url']=data['image'][0]
            original=parse_qs(urlsplit(result['image_url']).query).get('url')
            if original and urlsplit(original[0]).hostname=='cdn.thingiverse.com':result['image_url']=original[0]
        result['license_evidence']=str(evidence.resolve());result['group']=result['key'];result['original_url']=result['image_url']
        result=download(result,output)
    except Exception as error:result['status']='source_failed';result['error']=str(error)
    print(json.dumps({k:v for k,v in result.items() if k!='metadata'},ensure_ascii=False),flush=True)
    return result

def resolve_all(leads, output):
    output=Path(output);output.mkdir(parents=True,exist_ok=True)
    rows=[r for r in json.loads(Path(leads).read_text(encoding='utf-8')) if r['source_site'] in {'sketchfab','thingiverse'}]
    with ThreadPoolExecutor(max_workers=3) as pool:results=list(pool.map(lambda r:resolve(r,output),rows))
    (output/'模型预览核验.json').write_text(json.dumps(results,ensure_ascii=False,indent=2),encoding='utf-8');sheets(results,output)
    print('RESOLVED '+str(sum(bool(r.get('file')) for r in results)),flush=True)

if __name__=='__main__':
    import argparse
    p=argparse.ArgumentParser();p.add_argument('leads');p.add_argument('output');a=p.parse_args();resolve_all(a.leads,a.output)
