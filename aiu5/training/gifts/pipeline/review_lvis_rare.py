"""Render every available rare-class image with boxes and readable source IDs for curation."""
from pathlib import Path
from PIL import Image,ImageDraw
import json

ROOT=Path('D:/AIU5-YOLO训练资料/公开数据');OUT=ROOT/'lvis-review';DATA=ROOT/'dataset-v1'
if __name__=='__main__':
    allrows=json.loads((ROOT/'selection.json').read_text(encoding='utf-8'))
    for cid in (10,11,13,14):
        rows=[r for r in allrows if any(b[0]==cid for b in r['labels']) and (DATA/'images'/r['split']/(r['key']+'.jpg')).exists()]
        for start in range(0,len(rows),24):
            group=rows[start:start+24];sheet=Image.new('RGB',(1600,((len(group)+3)//4)*250),'#dddddd');d=ImageDraw.Draw(sheet)
            for i,r in enumerate(group):
                im=Image.open(DATA/'images'/r['split']/(r['key']+'.jpg')).convert('RGB');dr=ImageDraw.Draw(im);w,h=im.size
                for cls,x,y,bw,bh in r['labels']:
                    if cls==cid:dr.rectangle(((x-bw/2)*w,(y-bh/2)*h,(x+bw/2)*w,(y+bh/2)*h),outline='red',width=4)
                im.thumbnail((394,224));x=(i%4)*400;y=(i//4)*250;sheet.paste(im,(x+(400-im.width)//2,y));d.text((x+4,y+226),str(r['source_image_id'])+' '+r['split'],fill='black')
            sheet.save(OUT/f'rare_{cid}_{start:03d}.jpg')
        print(cid,len(rows))
