# YOLO 赐予模型与公开训练数据

已按要求自行收集公开照片，类别名为剑、斧、镐子、弓、盔甲、头盔、护腿、靴子，名称不带“玩具”。完整模型固定18类ID为0–17，游戏映射ID保持不变。

实际独立照片：训练545张，验证130张，测试8张。标注文件683份。每轮实际抽样921次，稀缺图片会重复抽样，重复次数不是新增照片。

当前状态：已完成首轮训练并在验证集评估。摄像头及祭台赐予已接入，首版模型的GPU链路和独立CPU链路均已实测推理、预览与释放。玩家真实装备款式的逐类效果仍未验收。

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

## 本轮结果

实际权重：`D:\AIU5-YOLO训练资料\公开数据\runs\gifts18-prototype-v1\weights\best.pt`。

```json
{
  "checkpoint": "D:\\AIU5-YOLO训练资料\\公开数据\\runs\\gifts18-prototype-v1\\weights\\best.pt",
  "run": "D:\\AIU5-YOLO训练资料\\公开数据\\runs\\gifts18-prototype-v1",
  "epochs_requested": 30,
  "imgsz": 512,
  "metrics": {
    "metrics/precision(B)": 0.4739953522587776,
    "metrics/recall(B)": 0.5661289675942581,
    "metrics/mAP50(B)": 0.5101185931798928,
    "metrics/mAP50-95(B)": 0.3353024440924645,
    "fitness": 0.3353024440924645
  },
  "per_class": {
    "cup": 0.3298571269660873,
    "knife": 0.18243486323491626,
    "bowl": 0.4578451230544823,
    "bed": 0.4511510098522168,
    "book": 0.14394289882434746,
    "scissors": 0.38220639517614213,
    "bird": 0.4614142613046634,
    "dog": 0.4789983420922198,
    "apple": 0.177354811693623,
    "carrot": 0.4381298757512665,
    "sword": 0.835,
    "axe": 0.995,
    "pickaxe": 0.5366666666666667,
    "bow": 0.995,
    "armor": 0.995,
    "helmet": 0.23524042484078317,
    "leggings": 0.995,
    "boots": 0.09189287778065741
  },
  "camera_integrated": false,
  "quality": "prototype, not accepted for game integration",
  "epochs_completed": 30
}
```

## 独立照片实际问题

已检查独立装备结果图：斧子被误识为剑，盐场镐子漏检。模型仍是初版，未通过游戏接入验收；不能把极小验证集上的高分当可靠性保证。模型及完整结果另存于`D:/AIU5-YOLO训练资料/公开数据/模型交付/`。

## 玩具风补充数据库

用户提供的 `D:/数据库/` 已只读审计，另存资源清单、9张初步标注图片和v2实验数据。分类名称保持不变；真实玩具照片只有2张，仍未验收摄像头效果。最新报告：`D:/AIU5-YOLO训练资料/玩具风补充/先看这里.md`。
