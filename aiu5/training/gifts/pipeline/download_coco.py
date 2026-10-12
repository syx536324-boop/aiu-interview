"""Download official COCO annotation metadata for complete boxes and image licenses."""
from pathlib import Path
import requests, time
if __name__=='__main__':
    target=Path('D:/AIU5-YOLO训练资料/公开数据/cache/annotations_trainval2017.zip')
    if not target.exists():
        temp=target.with_suffix('.part')
        with requests.get('https://s3.amazonaws.com/images.cocodataset.org/annotations/annotations_trainval2017.zip',stream=True,timeout=(20,90)) as r:
            r.raise_for_status();last=time.monotonic()
            with temp.open('wb') as f:
                for block in r.iter_content(1048576):
                    f.write(block)
                    if time.monotonic()-last>15:
                        print('COCO annotations',f.tell()//1048576,'MiB',flush=True);last=time.monotonic()
        temp.replace(target)
    print('COCO metadata ready',target.stat().st_size,flush=True)
