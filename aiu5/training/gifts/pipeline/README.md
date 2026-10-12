# 赐予模型训练脚本

数据下载、标注转换、质量检查与训练各自分开。`train_gifts.py`只组合检查和训练，不打开摄像头，不读取游戏存档。

运行环境：`D:/aiu2/.venv/Scripts/python.exe`，Ultralytics 8.4.173 / PyTorch 2.14.1+cu130。数据及模型实际保存在`D:/AIU5-YOLO训练资料/公开数据/`。

重新核验现有数据并训练：

```powershell
& D:/aiu2/.venv/Scripts/python.exe D:/aiu5/training/gifts/pipeline/train_gifts.py --epochs 30 --imgsz 512 --batch 8
```

每次训练保留新输出目录，日志中的实际save_dir为准。`dataset_check.py`检查18类训练/验证覆盖、文件完整性、框范围、重复照片与已记录的实物分组泄漏。

数据重新构建顺序：download_metadata、download_coco、prepare_lvis、inspect_metadata、prepare_commons、museum_candidates、prepare_museum、review_lvis_rare、write_curation、finalize_dataset。`prepare_commons.py`、`prepare_museum.py`和`write_curation.py`包含本轮逐图检查记录；换照片后必须重新检查，不能把旧框套到新图。

COCO/LVIS使用官方框；Commons和博物馆补充照片是AI检查并手工放置的初步框，不是人工验收的金标数据。装备抽样列表会重复使用稀缺照片，重复次数不计入真实照片数量。测试集仅覆盖少数补充装备，不能代表全部18类的独立上线验收。真实玩家摄像头及实际装备款式尚未验证。
