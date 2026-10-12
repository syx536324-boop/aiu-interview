"""Cache official LVIS annotations and inspect open museum/Commons data services."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import json, requests, time

ROOT = Path('D:/AIU5-YOLO训练资料/公开数据/cache')
ROOT.mkdir(parents=True, exist_ok=True)
def download(split):
    url = f'https://dl.fbaipublicfiles.com/LVIS/lvis_v1_{split}.json.zip'
    target = ROOT / f'lvis_v1_{split}.json.zip'
    if target.exists():
        print(f'{split}: cached {target.stat().st_size}', flush=True)
        return
    temp = target.with_suffix('.zip.part')
    with requests.get(url, stream=True, timeout=(20, 120)) as r:
        r.raise_for_status()
        last = time.monotonic()
        with temp.open('wb') as f:
            for chunk in r.iter_content(1024 * 1024):
                f.write(chunk)
                if time.monotonic() - last > 15:
                    print(f'{split}: {f.tell() // 1048576} MiB', flush=True)
                    last = time.monotonic()
    temp.replace(target)
    print(f'{split}: complete {target.stat().st_size}', flush=True)

def probe(name, url, params=None):
    try:
        r = requests.get(url, params=params, timeout=35, headers={'User-Agent':'AIU5DatasetResearch/1.0 (local educational prototype)'})
        (ROOT / (name + '.json')).write_text(r.text, encoding='utf-8')
        print(f'{name}: {r.status_code}, {len(r.content)} bytes', flush=True)
    except Exception as e:
        print(f'{name}: {e}', flush=True)

if __name__ == '__main__':
    with ThreadPoolExecutor(max_workers=5) as pool:
        jobs = [pool.submit(download, s) for s in ('train','val')]
        jobs += [pool.submit(probe, 'cleveland_greaves','https://openaccess-api.clevelandart.org/api/artworks/', {'q':'greaves','has_image':1,'limit':100}),
                 pool.submit(probe, 'commons_pickaxes','https://commons.wikimedia.org/w/api.php', {'action':'query','generator':'categorymembers','gcmtitle':'Category:Pickaxes','gcmtype':'file','gcmlimit':100,'prop':'imageinfo','iiprop':'url|extmetadata','iiurlwidth':960,'format':'json'}),
                 pool.submit(probe, 'commons_greaves','https://commons.wikimedia.org/w/api.php', {'action':'query','generator':'categorymembers','gcmtitle':'Category:Greaves in the Metropolitan Museum of Art','gcmtype':'file','gcmlimit':100,'prop':'imageinfo','iiprop':'url|extmetadata','iiurlwidth':960,'format':'json'})]
        for job in jobs:
            job.result()
