"""Add visually selected CC0 equipment photos with explicit approximate object boxes."""
from pathlib import Path
from collections import defaultdict
from PIL import Image, ImageDraw
import json, random, hashlib

ROOT=Path('D:/AIU5-YOLO训练资料/公开数据');SRC=ROOT/'museum-review';DATA=ROOT/'dataset-v1'
BOXES={
0:(.38,.08,.64,.94),1:(.32,.08,.68,.94),2:(.34,.05,.68,.96),7:(.43,.06,.81,.97),8:(.32,.05,.65,.94),10:(.35,.08,.63,.93),13:(.31,.07,.70,.92),14:(.36,.10,.67,.97),17:(.40,.07,.73,.94),19:(.31,.11,.65,.94),20:(.32,.07,.66,.95),21:(.26,.08,.75,.94),22:(.29,.07,.68,.96),23:(.25,.07,.71,.94),24:(.35,.05,.70,.95),26:(.28,.03,.68,.95),27:(.36,.07,.73,.96),28:(.06,.45,.90,.70),29:(.35,.08,.70,.95),30:(.33,.10,.70,.92),31:(.33,.10,.72,.95),32:(.32,.05,.68,.95),33:(.32,.05,.70,.96),34:(.32,.10,.67,.96),35:(.39,.04,.80,.96),38:(.30,.06,.66,.96),39:(.31,.07,.68,.97),40:(.32,.08,.70,.97),41:(.34,.05,.68,.96),48:(.30,.05,.72,.94),49:(.30,.09,.68,.94),51:(.33,.10,.68,.96),56:(.32,.08,.70,.96),57:(.32,.10,.69,.95),64:(.32,.07,.72,.95),65:(.30,.08,.75,.95),66:(.09,.28,.93,.50),
72:(.27,.05,.80,.98),74:(.29,.07,.82,.96),77:(.42,.05,.83,1.0),81:(.31,.08,.72,.97),88:(.35,.08,.77,.96),89:(.30,.07,.81,.98),94:(.06,.51,.96,.81),
102:(.33,.06,.70,.95),108:(.11,.12,.88,.92),109:(.28,.05,.68,.96),113:(.33,.04,.74,.97),
116:(.22,.08,.80,.92),117:(.26,.10,.84,.96),118:(.16,.06,.81,.95),119:(.20,.08,.83,.96),122:(.20,.10,.85,.96),124:(.16,.10,.85,.95),125:(.23,.11,.84,.96),126:(.05,.10,.88,.97),127:(.20,.09,.86,.93),
}
def main():
    candidates=json.loads((SRC/'candidates.json').read_text(encoding='utf-8'))
    selected=[r for r in candidates if r['index'] in BOXES]
    groups=defaultdict(list)
    for r in selected:groups[r['class_id']].append(r['group'])
    split_for={}
    for cid,values in groups.items():
        values=sorted(set(values));random.Random(20261011+cid).shuffle(values)
        nval=max(1,round(len(values)*.15));ntest=max(1,round(len(values)*.10)) if len(values)>=7 else 0
        for i,g in enumerate(values):split_for[g]='val' if i<nval else 'test' if i<nval+ntest else 'train'
    rows=[]
    for r in selected:
        split=split_for[r['group']];source=SRC/(r['key']+'.jpg')
        with Image.open(source) as im:w,h=im.size
        x1,y1,x2,y2=BOXES[r['index']];labels=[[r['class_id'],(x1+x2)/2,(y1+y2)/2,x2-x1,y2-y1]]
        if r['index']==117:x1=.14
        if r['index']==116:x1=.15;x2=.86
        if r['index']==124:x1=.12
        if r['index']==125:x1=.16
        if r['index']==126:x1=.01
        if r['index'] in (0,1,2,14,19,20,21,22,23,24,29,32,41,56,57,64):x1=max(0,x1-.07);x2=min(1,x2+.05)
        if r['index'] in (72,74,77,81,88,89):x1=max(0,x1-.08);x2=min(1,x2+.06)
        labels=[[r['class_id'],(x1+x2)/2,(y1+y2)/2,x2-x1,y2-y1]]
        out=DATA/'images'/split/source.name;out.parent.mkdir(parents=True,exist_ok=True)
        Image.open(source).convert('RGB').save(out,quality=95)
        label=DATA/'labels'/split/(r['key']+'.txt');label.parent.mkdir(parents=True,exist_ok=True)
        label.write_text(str(r['class_id'])+' '+' '.join(f'{v:.7f}' for v in labels[0][1:])+'\n',encoding='utf-8')
        rows.append(dict(r,split=split,width=w,height=h,labels=labels,source='Cleveland Museum of Art Open Access',annotation_status='AI visual selection and manually placed approximate boxes; prototype quality, not human-reviewed gold labels',sha256=hashlib.sha256(out.read_bytes()).hexdigest()))
    (DATA/'museum-manifest.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf-8')
    for start in range(0,len(rows),24):
        subset=rows[start:start+24];sheet=Image.new('RGB',(1440,((len(subset)+5)//6)*210),'#dddddd');d=ImageDraw.Draw(sheet)
        for i,r in enumerate(subset):
            im=Image.open(DATA/'images'/r['split']/(r['key']+'.jpg'));dr=ImageDraw.Draw(im);w,h=im.size
            for cls,x,y,bw,bh in r['labels']:dr.rectangle(((x-bw/2)*w,(y-bh/2)*h,(x+bw/2)*w,(y+bh/2)*h),outline='red',width=4)
            im.thumbnail((234,184));x=(i%6)*240;y=(i//6)*210;sheet.paste(im,(x+(240-im.width)//2,y));d.text((x+3,y+185),f'{r["index"]} / {r["split"]}',fill='black')
        sheet.save(SRC/f'labels_review_{start:03d}.jpg')
    print('MUSEUM ANNOTATED',len(rows),flush=True)
if __name__=='__main__':main()
