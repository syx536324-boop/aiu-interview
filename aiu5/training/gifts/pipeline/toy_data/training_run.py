"""Fine-tune a prototype and compare both checkpoints on identical held-out data without game integration."""
from pathlib import Path
import os, csv, json, hashlib, shutil

def metric_dict(result):
    return {k:float(v) for k,v in result.results_dict.items()}

def train_and_compare(root, dataset, weights, epochs, imgsz, batch):
    root,dataset,weights=map(Path,(root,dataset,weights))
    config=root/'ultralytics-config';config.mkdir(parents=True,exist_ok=True)
    os.environ['YOLO_CONFIG_DIR']=str(config);os.environ['YOLO_OFFLINE']='true';os.environ['OMP_NUM_THREADS']='2'
    import torch,yaml
    from ultralytics import YOLO
    torch.set_num_threads(2)
    data=str(dataset/'data.yaml');project=str(root/'runs');names=yaml.safe_load((dataset/'data.yaml').read_text(encoding='utf-8'))['names']
    baseline=YOLO(str(weights)).val(data=data,device=0,workers=0,imgsz=imgsz,batch=batch,plots=False,project=project,name='gifts18-v2-baseline',exist_ok=False,verbose=False)
    model=YOLO(str(weights))
    model.train(data=data,epochs=epochs,imgsz=imgsz,batch=batch,device=0,workers=0,cache=False,amp=False,seed=20261011,deterministic=True,project=project,name='gifts18-toy-supplement-v2',exist_ok=False,patience=epochs,save=True,plots=True,verbose=False,close_mosaic=3,lr0=.001)
    run=Path(model.trainer.save_dir);best=run/'weights/best.pt'
    trained=YOLO(str(best));result=trained.val(data=data,device=0,workers=0,imgsz=imgsz,batch=batch,plots=True,project=project,name='gifts18-v2-evaluation',exist_ok=False,verbose=False)
    # Both checkpoints see the same original eight + two new held-out images, never training examples.
    tests={}
    for label,path in (('v1',weights),('v2',best)):
        tests[label]=metric_dict(YOLO(str(path)).val(data=data,split='test',device=0,workers=0,imgsz=imgsz,batch=batch,plots=True,project=project,name='gifts18-v2-test-'+label,exist_ok=False,verbose=False))
    report={'model_status':'experimental_prototype_camera_unverified','initial_checkpoint':str(weights),'checkpoint':str(best),'run':str(run),'epochs_requested':epochs,'epochs_completed':len(list(csv.DictReader((run/'results.csv').open(encoding='utf-8')))),'same_validation_set':{'baseline_v1':metric_dict(baseline),'candidate_v2':metric_dict(result)},'same_test_set':tests,'per_class_AP50':{names[int(c)]:float(v) for c,v in zip(result.box.ap_class_index,result.box.ap50)},'camera_integrated':False,'ready_for_game_integration':False,'limitations':['Nine-image supplement: only two real toy photos and seven model renders.','New test images cover armor and helmet only; most classes have no new toy-domain test samples.','Model is not accepted on the basis of tiny validation/test samples.']}
    report['promotion_decision']='keep_v1; v2 is experimental only, not an accepted replacement'
    report['promotion_reason']='Tiny toy supplement and mixed metrics do not demonstrate reliable improvement; camera-domain validation is absent.'
    delivery=root/'模型交付';delivery.mkdir(parents=True,exist_ok=True);target=delivery/'gifts18-toy-supplement-v2.pt';shutil.copy2(best,target)
    report.update(delivery=str(target),sha256=hashlib.sha256(target.read_bytes()).hexdigest())
    (root/'training-result-v2.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    print('TRAINING_FINISHED '+json.dumps(report,ensure_ascii=False),flush=True)
    return report
