"""Compose validation and the supplemental prototype trainer; no camera or game actions."""
from pathlib import Path
import argparse, json
from dataset_check import validate
from training_run import train_and_compare

def main():
    import yaml
    p=argparse.ArgumentParser();p.add_argument('--root',type=Path,required=True);p.add_argument('--data',type=Path,required=True);p.add_argument('--weights',type=Path,required=True);p.add_argument('--epochs',type=int,default=12);p.add_argument('--imgsz',type=int,default=512);p.add_argument('--batch',type=int,default=8);a=p.parse_args()
    names=yaml.safe_load((a.data/'data.yaml').read_text(encoding='utf-8'))['names'];print(json.dumps(validate(a.data,names),ensure_ascii=False),flush=True)
    train_and_compare(a.root,a.data,a.weights,a.epochs,a.imgsz,a.batch)
if __name__=='__main__':main()
