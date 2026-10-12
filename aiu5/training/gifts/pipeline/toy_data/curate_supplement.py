"""Build explicitly reviewed part boxes and independent model-group splits for a small supplement."""
from pathlib import Path
from collections import Counter
from PIL import Image, ImageDraw
import json, hashlib

# Class IDs refer to the stable final 18 classes. Coordinates are XYXY fractions of the image.
PLAN={
 'sketchfab_8228efdddbc240fca37107c5057932ad':('train','3D_render',[(15,.296,.073,.681,.944)]),
 'sketchfab_176691f0106b4d238629a1c861ce41fb':('train','3D_render',[(14,.39,.35,.59,.766),(16,.43,.764,.496,.914),(16,.501,.758,.556,.903),(17,.439,.91,.496,.973),(17,.505,.89,.568,.948)]),
 'thingiverse_5947944':('train','physical_toy_photo',[(14,.183,.418,.449,.745),(15,.35,.604,.65,.981),(15,.546,.481,.748,.733),(15,.712,.501,.793,.598),(10,.778,.521,.84,.677)]),
 'thingiverse_6590008':('val','3D_render',[(15,.334,.219,.713,.861)]),
 'thingiverse_5487847':('train','3D_render',[(14,.091,.267,.831,.775)]),
 'thingiverse_4310278':('test','physical_toy_photo',[(15,.368,.163,.699,.392),(14,.304,.391,.684,.746)]),
 'sketchfab_0735f75fffe643c3a5dd30f0e76bc041':('train','3D_render',[(15,.431,.264,.553,.472),(14,.417,.405,.585,.669),(17,.443,.624,.496,.772),(17,.51,.633,.56,.774)]),
 'sketchfab_9344457736d24727ba51e8bd6f3f2389':('val','3D_render',[(14,.276,.109,.731,.937)]),
 'sketchfab_7717807561cf42138569edbcd1adcb01':('test','3D_render',[(14,.302,.151,.614,.999)]),
}
REJECTED={
 'thingiverse_3973219':'Promotional composite with large text, watermark and stylized body-part boundaries; retained for review only.',
 'sketchfab_7e8485a272784e6cb3b5bda68ff319fa':'Three dark and very similar full armor variants; not used in this toy-focused small supplement.',
 'sketchfab_7e5ba2d8f41e447984ef54eacab37ef2':'Character turnarounds; clothing and armor boundaries insufficiently clear for these four equipment classes.',
}

def curate(source, output):
    source,output=Path(source),Path(output);output.mkdir(parents=True,exist_ok=True)
    rows=json.loads((source/'模型预览核验.json').read_text(encoding='utf-8'));manifest=[];review=[]
    for row in rows:
        key=row['key']
        if key not in PLAN:
            review.append({'key':key,'decision':'excluded','reason':REJECTED.get(key,row['status'])});continue
        split,domain,rects=PLAN[key];im=Image.open(source/row['file']).convert('RGB')
        if key=='thingiverse_4310278':
            # Crop off the ambiguous, partially cut-off weapon and lower legs. Original remains untouched.
            old_h=im.height;bottom=round(old_h*.72);im=im.crop((0,0,im.width,bottom))
            rects=[(c,x1,y1*old_h/bottom,x2,min(y2*old_h/bottom,1.)) for c,x1,y1,x2,y2 in rects]
            row['preprocessing']='Upper-body crop to y=0.72; lower ambiguous weapon and legs excluded.'
        boxes=[[c,(x1+x2)/2,(y1+y2)/2,x2-x1,y2-y1] for c,x1,y1,x2,y2 in rects]
        image=output/'images'/split/(key+'.jpg');label=output/'labels'/split/(key+'.txt');image.parent.mkdir(parents=True,exist_ok=True);label.parent.mkdir(parents=True,exist_ok=True)
        im.save(image,quality=95);label.write_text('\n'.join(str(b[0])+' '+' '.join(f'{v:.7f}' for v in b[1:]) for b in boxes)+'\n',encoding='utf-8')
        item={**row,'key':key,'split':split,'domain':domain,'source':row['source_page'].split('/')[2], 'url':row['image_url'],'labels':boxes,'width':im.width,'height':im.height,'annotation_status':'AI visual review and manually placed approximate part boxes; not human-certified gold labels','sha256':hashlib.sha256(image.read_bytes()).hexdigest()}
        manifest.append(item);review.append({'key':key,'decision':'accepted','split':split,'domain':domain,'instances':len(boxes)})
    (output/'manifest-final.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8');(output/'筛选记录.json').write_text(json.dumps(review,ensure_ascii=False,indent=2),encoding='utf-8')
    canvas=Image.new('RGB',(1500,((len(manifest)+2)//3)*340),'#ededed');draw=ImageDraw.Draw(canvas)
    for i,row in enumerate(manifest):
        im=Image.open(output/'images'/row['split']/(row['key']+'.jpg'));d=ImageDraw.Draw(im);w,h=im.size
        for c,x,y,bw,bh in row['labels']:
            bounds=((x-bw/2)*w,(y-bh/2)*h,(x+bw/2)*w,(y+bh/2)*h);d.rectangle(bounds,outline='red',width=max(2,w//350));d.text((bounds[0],bounds[1]),str(c),fill='red',stroke_width=1)
        im.thumbnail((490,306));x=(i%3)*500;y=(i//3)*340;canvas.paste(im,(x+(500-im.width)//2,y));draw.text((x+4,y+308),row['key'][-12:]+' '+row['split'],fill='black')
    canvas.save(output/'标注预览.jpg')
    summary={'images':len(manifest),'splits':dict(Counter(r['split'] for r in manifest)),'domains':dict(Counter(r['domain'] for r in manifest)),'instances':dict(Counter(c for r in manifest for c,*box in r['labels'])),'limitations':['Only two physical toy photos; seven 3D renders are supplementary and not camera-domain validation.','No new usable axe, pickaxe, bow samples in this supplied database.','Not all classes have new validation/test examples.']}
    (output/'补充统计.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8');return summary

if __name__=='__main__':
    import argparse
    p=argparse.ArgumentParser();p.add_argument('source');p.add_argument('output');a=p.parse_args();print(json.dumps(curate(a.source,a.output),ensure_ascii=False,indent=2))
