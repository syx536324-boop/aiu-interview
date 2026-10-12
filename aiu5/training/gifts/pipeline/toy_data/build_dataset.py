"""Copy the frozen v1 dataset and reviewed supplement into a separate v2 dataset with traceable splits."""
from pathlib import Path
from collections import Counter
import shutil, json, hashlib
import yaml
from dataset_check import validate

def build(base, supplement, output):
    base,supplement,output=map(Path,(base,supplement,output))
    if output.exists():raise FileExistsError('Refusing to overwrite dataset: '+str(output))
    output.mkdir(parents=True)
    config=yaml.safe_load((base/'data.yaml').read_text(encoding='utf-8'));manifest=[]
    for root in (base,supplement):
        for row in json.loads((root/'manifest-final.json').read_text(encoding='utf-8')):
            for folder,extension in (('images','.jpg'),('labels','.txt')):
                source=root/folder/row['split']/(row['key']+extension);target=output/folder/row['split']/source.name;target.parent.mkdir(parents=True,exist_ok=True)
                shutil.copy2(source,target)
            row['sha256']=hashlib.sha256((output/'images'/row['split']/(row['key']+'.jpg')).read_bytes()).hexdigest();manifest.append(row)
    config.update(path=output.as_posix(),train='train-balanced.txt',val='images/val',test='images/test')
    (output/'data.yaml').write_text(yaml.safe_dump(config,sort_keys=False,allow_unicode=True),encoding='utf-8')
    # Preserve v1's rare-equipment sampling; add three appearances per new training image, not three photos.
    lines=[str(output/'images/train'/Path(line.strip()).name) for line in (base/'train-balanced.txt').read_text(encoding='utf-8').splitlines() if line.strip()]
    new=[r for r in manifest if r.get('domain') and r['split']=='train']
    lines.extend(str(output/'images/train'/(r['key']+'.jpg')) for _ in range(3) for r in new)
    (output/'train-balanced.txt').write_text('\n'.join(lines)+'\n',encoding='utf-8');(output/'manifest-final.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    report=validate(output,config['names']);report['effective_train_samples']=len(lines);report['unique_train_images']=sum(r['split']=='train' for r in manifest);report['limitations'].append('Toy supplement has only two real toy photos and seven 3D renders; toy-camera recognition is unverified.')
    (output/'validation-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    return report
