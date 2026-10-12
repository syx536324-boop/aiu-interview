"""Record inspected failure cases, verify source/model integrity and finish the supplemental delivery."""
from pathlib import Path
import json, hashlib, shutil, ast
from collections import Counter
from publish_report import publish, ROOT, PROJECT

def finish():
    path=ROOT/'training-result-v2.json';result=json.loads(path.read_text(encoding='utf-8'))
    result['promotion_decision']='keep_v1; v2 is experimental only, not an accepted replacement'
    result['promotion_reason']='mAP50 decreased on the same validation/test sets; small mAP50-95 gains do not establish camera-domain improvement.'
    result['visually_confirmed_failures']=[
        {'image':'cleveland_104118.jpg','issue':'Axe still predicted as sword in both v1 and v2.'},
        {'image':'commons_106_77173505.jpg','issue':'Pickaxe still missed in both v1 and v2.'},
        {'image':'thingiverse_4310278.jpg','issue':'Toy knight helmet missed; predicted armor box also includes the head.'},
    ]
    path.write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
    (ROOT/'模型交付/model-card.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
    model=Path(result['delivery'])
    assert hashlib.sha256(model.read_bytes()).hexdigest()==result['sha256']
    v1=Path('D:/AIU5-YOLO训练资料/公开数据/模型交付/gifts18-prototype-v1.pt')
    assert hashlib.sha256(v1.read_bytes()).hexdigest()=='5a7bb20f5bf0d86ca32bcf82447012fe088cdcb3791ef275d2f4fbc2353a6a8b'
    incoming=Path('D:/数据库');audit=json.loads((ROOT/'audit/数据库检查.json').read_text(encoding='utf-8'))
    assert all(hashlib.sha256((incoming/r['path']).read_bytes()).hexdigest()==r['sha256'] for r in audit['files'])
    assert hashlib.sha256((incoming/'toy_armor_3d.db').read_bytes()).hexdigest()==audit['sqlite']['sha256']
    for source in Path(__file__).parent.glob('*.py'):
        ast.parse(source.read_text(encoding='utf-8'))
        if source.name not in {'install_supplement.py'}:shutil.copy2(source,PROJECT/'pipeline/toy_data'/source.name)
    rows=json.loads((ROOT/'dataset-v2/manifest-final.json').read_text(encoding='utf-8'));report=json.loads((ROOT/'dataset-v2/validation-report.json').read_text(encoding='utf-8'))
    report['effective_train_samples']=len((ROOT/'dataset-v2/train-balanced.txt').read_text(encoding='utf-8').splitlines());report['toy_supplement_images']=9;report['limitations'].append('New toy supplement: two real photos, seven renders. No toy-camera acceptance.')
    (ROOT/'dataset-v2/validation-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    checks={'source_files_unchanged':True,'v1_checkpoint_unchanged':True,'v2_hash_matches':True,'labels_and_splits_passed':report['ok'],'dataset_images':dict(Counter(r['split'] for r in rows)),'epochs_completed':result['epochs_completed'],'promoted':False}
    (ROOT/'交付核验.json').write_text(json.dumps(checks,ensure_ascii=False,indent=2),encoding='utf-8');publish();print(json.dumps(checks,ensure_ascii=False,indent=2))
if __name__=='__main__':finish()
