"""Compose the validated dataset and local YOLO trainer; do not open the camera or modify saves."""
from pathlib import Path
import os, argparse, json, csv
from dataset_check import validate

ROOT=Path('D:/AIU5-YOLO训练资料/公开数据')
def main():
    parser=argparse.ArgumentParser();parser.add_argument('--epochs',type=int,default=30);parser.add_argument('--imgsz',type=int,default=512);parser.add_argument('--batch',type=int,default=8);args=parser.parse_args()
    config=ROOT/'ultralytics-config';config.mkdir(exist_ok=True)
    os.environ['YOLO_CONFIG_DIR']=str(config);os.environ['YOLO_OFFLINE']='true';os.environ['OMP_NUM_THREADS']='2'
    import torch, yaml
    from ultralytics import YOLO
    torch.set_num_threads(2)
    data=ROOT/'dataset-v1';names=yaml.safe_load((data/'data.yaml').read_text(encoding='utf-8'))['names']
    report=validate(data,names);print(json.dumps(report,ensure_ascii=False),flush=True)
    model=YOLO('D:/aiu2/models/yolo11n.pt')
    model.train(data=str(data/'data.yaml'),epochs=args.epochs,imgsz=args.imgsz,batch=args.batch,device=0,workers=0,cache=False,amp=False,seed=20261011,deterministic=True,project=str(ROOT/'runs'),name='gifts18-prototype-v1',exist_ok=False,patience=10,save=True,plots=True,verbose=False,close_mosaic=5)
    run=Path(model.trainer.save_dir)
    best=run/'weights/best.pt'
    results=YOLO(str(best)).val(data=str(data/'data.yaml'),device=0,batch=args.batch,imgsz=args.imgsz,workers=0,plots=True,project=str(ROOT/'runs'),name='gifts18-evaluation-v1',exist_ok=False,verbose=False)
    metrics={'checkpoint':str(best),'run':str(run),'epochs_requested':args.epochs,'imgsz':args.imgsz,'metrics':{k:float(v) for k,v in results.results_dict.items()},'per_class':{names[int(cid)]:float(value) for cid,value in zip(results.box.ap_class_index,results.box.ap50)},'camera_integrated':False,'quality':'prototype, not accepted for game integration'}
    with (run/'results.csv').open(encoding='utf-8') as f:metrics['epochs_completed']=len(list(csv.DictReader(f)))
    (ROOT/'training-result.json').write_text(json.dumps(metrics,ensure_ascii=False,indent=2),encoding='utf-8')
    print('TRAINING_FINISHED '+json.dumps(metrics,ensure_ascii=False),flush=True)
if __name__=='__main__':main()
