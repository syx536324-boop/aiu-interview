# 玩具风数据导入与补训

`audit_database.py`只读审计输入；`resolve_models.py`核验原站许可和预览；`curate_supplement.py`保存逐图人工放置的近似部件框；`build_dataset.py`生成独立数据；`dataset_check.py`检查几何、图片、类别与分组；`training_run.py`拥有训练和对照评估；入口`train_supplement.py`仅解析配置、验证并启动，不操作游戏或摄像头。`publish_report.py`写报告和分类计划。

无需新增依赖，使用现有环境：Ultralytics 8.4.173、PyTorch 2.14.1+cu130、Pillow、PyYAML。数据和报告在`D:/AIU5-YOLO训练资料/玩具风补充/`。

```powershell
& D:/aiu2/.venv/Scripts/python.exe D:/aiu5/training/gifts/pipeline/toy_data/train_supplement.py --root D:/AIU5-YOLO训练资料/玩具风补充 --data D:/AIU5-YOLO训练资料/玩具风补充/dataset-v2 --weights D:/AIU5-YOLO训练资料/公开数据/模型交付/gifts18-prototype-v1.pt --epochs 12 --imgsz 512 --batch 8
```

再次训练由Ultralytics创建新run目录，实际输出以日志中的save_dir为准；交付文件名保留v2实验含义。现有README和统计保留首版基准，v2作为单独实验追加。更换图片后必须重新查看并修改PLAN，不能把当前框复制到其他图片。许可证、照片域、模型分组和原始URL保存在manifest中。
