"""Publish truthful dataset counts and training status into both user-facing D-drive catalogues."""
from pathlib import Path
from collections import Counter
import json,csv,shutil

EXPORT=Path('D:/AIU5-YOLO训练资料');ROOT=EXPORT/'公开数据';DATA=ROOT/'dataset-v1';PROJECT=Path('D:/aiu5/training/gifts')
def main():
    rows=json.loads((DATA/'manifest-final.json').read_text(encoding='utf-8'))
    summary=json.loads((DATA/'dataset-summary.json').read_text(encoding='utf-8'))
    result=json.loads((ROOT/'training-result.json').read_text(encoding='utf-8')) if (ROOT/'training-result.json').exists() else None
    status='prototype_trained_camera_unverified' if result else 'training_in_progress'
    for path,custom in ((PROJECT/'catalog.json',False),(EXPORT/'完整18类/类别映射.json',False),(EXPORT/'新增装备8类/装备类别.json',True)):
        data=json.loads(path.read_text(encoding='utf-8'));subset=[r for r in rows if not custom or any(b[0]>=10 for b in r['labels'])]
        data.update(status=status,training_images=sum(r['split']=='train' for r in subset),validation_images=sum(r['split']=='val' for r in subset),test_images=sum(r['split']=='test' for r in subset),annotation_files=len(subset),trained_custom_model=bool(result),camera_integrated=False,dataset_path=DATA.as_posix(),quality='公开照片初版；真实摄像头未验收；补充框为AI复核的近似框')
        for c in data['classes']:
            cid=c['class_id'];c['images_by_split']={s:sum(r['split']==s and any(b[0]==cid for b in r['labels']) for r in rows) for s in ('train','val','test')}
            c['instances_by_split']={s:sum(r['split']==s for r in rows for b in r['labels'] if b[0]==cid) for s in ('train','val','test')}
        path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    catalog=json.loads((PROJECT/'catalog.json').read_text(encoding='utf-8'))
    names={c['class_id']:c['class_name'] for c in catalog['classes']}
    import yaml
    actual=yaml.safe_load((DATA/'data.yaml').read_text(encoding='utf-8'))
    for path in (PROJECT/'data.yaml',EXPORT/'完整18类/data.yaml'):path.write_text(yaml.safe_dump(actual,allow_unicode=True,sort_keys=False),encoding='utf-8')
    with (EXPORT/'新增装备8类/采集计划.csv').open('w',encoding='utf-8-sig',newline='') as f:
        w=csv.writer(f);w.writerow(['类别','英文','计划最少照片','计划最多照片','已有独立照片','已有标注文件','状态','重点'])
        for c in catalog['classes'][10:]:
            n=sum(c['images_by_split'].values());w.writerow([c['name_zh'],c['class_name'],300,500,n,n,'公开数据初版；仍需实拍补充',c['note']])
    text=f'''# YOLO 赐予模型与公开训练数据

已按要求自行收集公开照片，类别名为剑、斧、镐子、弓、盔甲、头盔、护腿、靴子，名称不带“玩具”。完整模型固定18类ID为0–17，游戏映射ID保持不变。

实际独立照片：训练{summary['images']['train']}张，验证{summary['images']['val']}张，测试{summary['images']['test']}张。标注文件{len(rows)}份。每轮实际抽样{summary['effective_training_samples_per_epoch']}次，稀缺图片会重复抽样，重复次数不是新增照片。

当前状态：{'已完成首轮训练并在验证集评估' if result else '已启动GPU训练，尚未完成'}。摄像头及祭台赐予尚未接入，玩家真实装备款式的效果尚未验收。

## 直接查看

- 实际照片与YOLO框：`D:/AIU5-YOLO训练资料/公开数据/dataset-v1/images/`及`labels/`。
- 逐类数量：`D:/AIU5-YOLO训练资料/公开数据/类别样本数量.csv`。
- 图片来源、许可、分组、SHA256和标注性质：`dataset-v1/manifest-final.json`。
- 检查报告：`dataset-v1/dataset-summary.json`，18类训练/验证覆盖、图片完整性、框范围、已记录分组及重复图片检查通过。
- 训练日志：`D:/AIU5-YOLO训练资料/公开数据/training.log`。
- 模型、参数与训练曲线：`D:/AIU5-YOLO训练资料/公开数据/runs/`；实际运行目录见日志。
- 逐图放置的初步框检查图：`commons-review/labels_review_*.jpg`与`museum-review/labels_review_*.jpg`。这些框由AI逐图检查，不是人工验收的金标。

## 来源及选择

日常物品使用[COCO2017](https://cocodataset.org/#download)官方框，装备补充[LVIS-v1](https://www.lvisdataset.org/)官方框。仅保留COCO记录为CC BY、CC BY-SA或美国政府作品的照片；逐图来源和许可在manifest中。图案、雕像和未复核的稀缺装备图片排除。剑、斧、弓和胸甲另从[Cleveland Museum of Art Open Access](https://www.clevelandart.org/open-access)收集CC0实物照片；镐子和腿部护甲从[Wikimedia Commons](https://commons.wikimedia.org/)收集，保留各自作者、来源和许可元数据。许可信息不等于模型表现保证。

## 本轮限制

弓只有3个训练实例、1个验证实例；斧只有7个训练实例、1个验证实例；胸甲只有9个训练实例、1个验证实例。其余逐类数量见CSV。装备照片以博物馆背景为主，尚不足以覆盖手持、遮挡、普通房间和实际玩具款式。8张测试图仅覆盖部分装备，不能当作全部18类的独立验收。后续需要增加独立实物、实际摄像头环境、负样本和人工复核框。

初版模型只能用作继续训练和实验，不宣称已达到游戏上线质量。材质、品质及魔法属性不由这些类别推断；只有后续祭台赐予确认的实例才会按玩法获得魔法标记。

## 再次训练

```powershell
& D:/aiu2/.venv/Scripts/python.exe D:/aiu5/training/gifts/pipeline/train_gifts.py --epochs 30 --imgsz 512 --batch 8
```

使用YOLO11n本地预训练权重、RTX 5070、512像素、batch 8、workers 0、关闭RAM缓存。数据下载、标注转换、检查与训练各自分开。代码及重建顺序见`D:/aiu5/training/gifts/pipeline/README.md`。不覆盖原有COCO8模型，不读取或改动游戏存档。
'''
    if result:
        text+='\n## 本轮结果\n\n实际权重：`'+result['checkpoint']+'`。\n\n```json\n'+json.dumps(result,ensure_ascii=False,indent=2)+'\n```\n'
    (ROOT/'先看这里.md').write_text(text,encoding='utf-8')
    (EXPORT/'先看这里.md').write_text(text+'\n旧的8类单独训练模板仅供类别查看；实际模型采用公开数据目录的完整18类配置。部分CSV若正由Excel占用，已另存为带“名称已更新”后缀的版本。\n',encoding='utf-8')
    (PROJECT/'README.md').write_text(text,encoding='utf-8')
    docs=Path('D:/aiu5/docs/YOLO祭台赐予方案.md');old=docs.read_text(encoding='utf-8');marker='\n## 公开数据训练现状\n'
    if marker in old:old=old.split(marker)[0]
    docs.write_text(old+marker+'\n最新状态、实际数据和模型结果以`../training/gifts/README.md`及D盘独立资料中的`公开数据/先看这里.md`为准。已按用户授权自行收集公开数据，旧文中的“当前无训练照片/待用户实拍”属于准备阶段记录。\n',encoding='utf-8')
    print(status,summary['images'],flush=True)
if __name__=='__main__':main()
