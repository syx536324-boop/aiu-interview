"""Convert visually reviewed real-object photos to explicit boxes with object-group splits."""
from pathlib import Path
from PIL import Image, ImageDraw
import json, shutil, hashlib

ROOT=Path('D:/AIU5-YOLO训练资料/公开数据')
SRC=ROOT/'commons-review'; DATA=ROOT/'dataset-v1'
# XYXY fractions refer to each source photo, not contact-sheet cell padding.
# Pair members are distinct boxes; open halves of one greave remain one instance.
PLAN={
4:('met_282','train',[(.30,.04,.74,.95)]),5:('met_282','train',[(.27,.05,.72,.96)]),
6:('met_282','train',[(.25,.04,.76,.95)]),7:('met_282','train',[(.26,.04,.74,.96)]),
8:('met_282','train',[(.26,.05,.84,.94)]),9:('met_282','train',[(.26,.06,.74,.93)]),
10:('met_282','train',[(.24,.04,.76,.94)]),11:('met_282','train',[(.27,.03,.75,.95)]),
12:('met_282','train',[(.26,.03,.76,.96)]),13:('met_282','train',[(.25,.06,.78,.94)]),
16:('met_279','train',[(.25,.02,.75,.96)]),17:('met_279','train',[(.22,.02,.77,.96)]),
18:('met_279','train',[(.24,.03,.76,.97)]),19:('met_279','train',[(.23,.04,.85,.96)]),
20:('met_279','train',[(.24,.02,.76,.98)]),23:('met_279','train',[(.22,.03,.78,.96)]),
24:('met_279','train',[(.20,.03,.88,.97)]),
32:('thessaloniki_pair','test',[(.20,.10,.48,.94),(.55,.08,.86,.92)]),
46:('romania_greave','val',[(.34,.17,.77,.98)]),
52:('roman_gbm','train',[(.14,.02,.46,.95),(.55,.02,.87,.96)]),
53:('roman_gbm','train',[(.20,.02,.83,.98)]),54:('roman_gbm','train',[(.20,.03,.84,.99)]),
55:('roman_gbm','train',[(.10,.12,.61,.99)]),
58:('denda_pair','train',[(.15,.19,.49,.97),(.55,.19,.88,.97)]),
61:('denda_pair','train',[(.14,.05,.49,.95),(.55,.16,.89,.96)]),
62:('vendrell_greave','train',[(.10,.08,.75,.92)]),
63:('pompeii_greave','val',[(.31,.05,.74,.92)]),
67:('rust_pick_flickr','train',[(.04,.39,.98,.88)]),
68:('rust_pick_flickr','train',[(.02,.19,.92,.72)]),
69:('museum_picks','train',[(.05,.15,.58,.83),(.59,.26,.92,.86)]),
70:('museum_picks','train',[(.07,.10,.58,.90),(.57,.24,.94,.85)]),
87:('blue_pick','val',[(.12,.10,.99,.87)]),
96:('auckland_607366','train',[(.15,.04,.82,.91)]),
97:('auckland_607366','train',[(.15,.04,.82,.89)]),
98:('auckland_607366','train',[(.15,.04,.85,.81)]),
100:('grass_pick','train',[(.01,.45,.99,.96)]),
102:('blue_pick','val',[(.01,.07,.98,.97)]),
106:('salinas_pick','test',[(.36,.14,.78,.68)]),
}
def prepare():
    rows=json.loads((SRC/'candidates.json').read_text(encoding='utf-8'))
    added=[]
    for r in rows:
        if r['index'] not in PLAN: continue
        group,split,rects=PLAN[r['index']]
        # Include straps and hinges in greave boxes after reviewing the first overlay sheet.
        if r['index'] in list(range(4,14))+[16,17,18,19,20,23,24]:
            rects=[(.15,y1,.92,y2) for x1,y1,x2,y2 in rects]
        path=SRC/r['file']
        with Image.open(path) as im: w,h=im.size
        labels=[[r['class_id'],(x1+x2)/2,(y1+y2)/2,x2-x1,y2-y1] for x1,y1,x2,y2 in rects]
        key='commons_'+path.stem
        out=DATA/'images'/split/(key+'.jpg');out.parent.mkdir(parents=True,exist_ok=True)
        # Convert PNGs to actual JPEG instead of only changing the extension.
        Image.open(path).convert('RGB').save(out,quality=95)
        label=DATA/'labels'/split/(key+'.txt');label.parent.mkdir(parents=True,exist_ok=True)
        label.write_text('\n'.join(str(b[0])+' '+' '.join(f'{v:.7f}' for v in b[1:]) for b in labels)+'\n',encoding='utf-8')
        added.append(dict(key=key,split=split,source='Wikimedia Commons',source_page=r['source_page'],url=r['original_url'],license=r['license'],metadata=r['metadata'],width=w,height=h,labels=labels,group=group,annotation_status='AI visual selection and manually placed approximate boxes; prototype quality, not human-reviewed gold labels',sha256=hashlib.sha256(out.read_bytes()).hexdigest()))
    (DATA/'commons-manifest.json').write_text(json.dumps(added,ensure_ascii=False,indent=2),encoding='utf-8')
    for start in range(0,len(added),24):
        subset=added[start:start+24];sheet=Image.new('RGB',(1440,((len(subset)+5)//6)*210),'#dddddd');draw=ImageDraw.Draw(sheet)
        for i,r in enumerate(subset):
            im=Image.open(DATA/'images'/r['split']/(r['key']+'.jpg'));d=ImageDraw.Draw(im);w,h=im.size
            for cls,x,y,bw,bh in r['labels']:d.rectangle(((x-bw/2)*w,(y-bh/2)*h,(x+bw/2)*w,(y+bh/2)*h),outline='red',width=4)
            im.thumbnail((232,185));x=(i%6)*240;y=(i//6)*210
            sheet.paste(im,(x+(240-im.width)//2,y));draw.text((x+4,y+187),r['key'].split('_')[1]+' '+r['split'],fill='black')
        sheet.save(SRC/f'labels_review_{start:03d}.jpg')
    print('Commons annotated photos',len(added),flush=True)
if __name__=='__main__':prepare()
