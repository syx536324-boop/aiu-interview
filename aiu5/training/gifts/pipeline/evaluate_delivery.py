"""Evaluate the small held-out equipment set and package the trained checkpoint with exact mappings."""
from pathlib import Path
import os,json,shutil,hashlib,csv

ROOT=Path('D:/AIU5-YOLO训练资料/公开数据');DATA=ROOT/'dataset-v1'
def main():
    os.environ['YOLO_CONFIG_DIR']=str(ROOT/'ultralytics-config');os.environ['YOLO_OFFLINE']='true';os.environ['OMP_NUM_THREADS']='2'
    import torch
    from ultralytics import YOLO
    torch.set_num_threads(2)
    result=json.loads((ROOT/'training-result.json').read_text(encoding='utf-8'))
    with (Path(result['run'])/'results.csv').open(encoding='utf-8') as f:result['epochs_completed']=len(list(csv.DictReader(f)))
    (ROOT/'training-result.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
    best=Path(result['checkpoint']);model=YOLO(str(best))
    expected=json.loads(Path('D:/aiu5/training/gifts/catalog.json').read_text(encoding='utf-8'))
    assert model.names=={r['class_id']:r['class_name'] for r in expected['classes']},'checkpoint mapping mismatch'
    metric=model.val(data=str(DATA/'data.yaml'),split='test',device=0,batch=8,imgsz=result['imgsz'],workers=0,plots=True,project=str(ROOT/'runs'),name='gifts18-heldout-equipment-v1',exist_ok=False,verbose=False)
    manifest=json.loads((DATA/'manifest-final.json').read_text(encoding='utf-8'));tested=sorted({b[0] for r in manifest if r['split']=='test' for b in r['labels']})
    report={'images':8,'tested_classes':[model.names[c] for c in tested],'missing_test_classes':[model.names[c] for c in model.names if c not in tested],'per_class_AP50':{model.names[int(c)]:float(v) for c,v in zip(metric.box.ap_class_index,metric.box.ap50)},'limitations':'Only 8 held-out equipment photos; not a complete 18-class test or real-camera acceptance.'}
    (ROOT/'heldout-equipment-result.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    predictions=model.predict(source=str(DATA/'images/test'),device=0,imgsz=result['imgsz'],conf=.25,save=True,save_txt=True,save_conf=True,project=str(ROOT/'runs'),name='gifts18-heldout-predictions-v1',exist_ok=False,verbose=False)
    delivery=ROOT/'模型交付';delivery.mkdir(exist_ok=True);shutil.copy2(best,delivery/'gifts18-prototype-v1.pt')
    shutil.copy2(Path('D:/aiu5/training/gifts/catalog.json'),delivery/'类别与游戏映射.json')
    info={'checkpoint':'gifts18-prototype-v1.pt','sha256':hashlib.sha256(best.read_bytes()).hexdigest(),'names':model.names,'camera_integrated':False,'validation':result,'heldout':report,'prediction_directory':str(predictions[0].save_dir) if predictions else None,'runtime':{'ultralytics':'8.4.173','torch':torch.__version__},'quality':'initial public-image prototype; not approved for game integration'}
    (delivery/'model-card.json').write_text(json.dumps(info,ensure_ascii=False,indent=2),encoding='utf-8')
    print('DELIVERY_READY '+json.dumps(info,ensure_ascii=False),flush=True)
if __name__=='__main__':main()
