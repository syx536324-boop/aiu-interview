"""Publish a concise audit, toy-style collection rules and experimental training status without replacing v1."""
from pathlib import Path
from collections import Counter
import csv, json, hashlib, shutil

ROOT=Path('D:/AIU5-YOLO训练资料/玩具风补充')
PROJECT=Path('D:/aiu5/training/gifts')
STYLE={
 10:('剑','积木短剑、泡沫剑、我的世界像素实体剑；剑柄、护手与剑刃可辨认。'),
 11:('斧','积木斧、塑料斧、像素实体斧；斧刃呈宽刃形，不能把镐头当斧刃。'),
 12:('镐子','积木镐、泡沫像素镐；横向镐头与握柄完整可见。'),
 13:('弓','玩具弓、积木弓、像素实体弓；保留弓臂与弦，排除弩和只有箭的照片。'),
 14:('盔甲','积木胸甲、儿童角色扮演胸甲、Q版胸甲；完整人偶需要按躯干部件框选。'),
 15:('头盔','积木头盔、儿童塑料头盔、像素实体头盔；普通帽子、面罩、皇冠不自动当头盔。'),
 16:('护腿','积木腿甲、塑料护胫、像素实体腿甲；护腿是腿部防具，排除普通长裤。'),
 17:('靴子','玩具人物靴子、角色扮演靴、像素实体靴；每只分别框选，排除一般便鞋。'),
}

def append_once(path, marker, text):
    content=path.read_text(encoding='utf-8') if path.exists() else ''
    if marker not in content:path.write_text(content.rstrip()+'\n\n'+text.rstrip()+'\n',encoding='utf-8')

def publish():
    audit=json.loads((ROOT/'audit/数据库检查.json').read_text(encoding='utf-8'));summary=json.loads((ROOT/'supplement/补充统计.json').read_text(encoding='utf-8'));result_path=ROOT/'training-result-v2.json';result=json.loads(result_path.read_text(encoding='utf-8')) if result_path.exists() else None
    guidance={'names_have_toy_prefix':False,'class_ids_unchanged':True,'primary_domain':'physical_toy_photo','secondary_domain':'3D_render','rules':['识别名称仍为剑、斧、镐子、弓、盔甲、头盔、护腿、靴子。','实物玩具照片优先；3D预览单独记录来源与许可，只用作补充。','同一实体玩具或同一3D模型的不同角度、裁剪图和衍生图不得跨训练/验证/测试集。','不把游戏截图、像素图标或无真实框选的满屏猜测标签当作摄像头训练样本。','整个人偶上的头盔、躯干盔甲、护腿、靴子分别标注；仅肩甲、腕甲不标成躯干盔甲。'],'classes':[{'class_id':cid,'name_zh':name,'appearance':desc} for cid,(name,desc) in STYLE.items()]}
    (ROOT/'玩具风分类规则.json').write_text(json.dumps(guidance,ensure_ascii=False,indent=2),encoding='utf-8')
    rows=json.loads((ROOT/'supplement/manifest-final.json').read_text(encoding='utf-8'))
    with (ROOT/'玩具风采集计划.csv').open('w',encoding='utf-8-sig',newline='') as f:
        writer=csv.writer(f);writer.writerow(['最终类别ID','名称','建议独立照片目标','本轮含该类图片','本轮标注目标数','外观范围','当前缺口'])
        for cid,(name,desc) in STYLE.items():
            count=sum(any(b[0]==cid for b in r['labels']) for r in rows);instances=sum(sum(b[0]==cid for b in r['labels']) for r in rows)
            writer.writerow([cid,name,'300-500',count,instances,desc,'继续自行寻找有许可的实体照片，补充不同款式/背景/距离；不能靠重复图片凑数量'])
    state='已生成独立v2数据集，训练进行中。'
    metrics=''
    if result:
        b=result['same_validation_set']['baseline_v1'];v=result['same_validation_set']['candidate_v2'];state=f"已完成 {result['epochs_completed']} 轮补训，模型单独保存在 `模型交付/gifts18-toy-supplement-v2.pt`。"
        metrics=f"\n在相同的132张验证图上比较：首版 mAP50={b['metrics/mAP50(B)']:.3f}，补训版={v['metrics/mAP50(B)']:.3f}；mAP50-95由{b['metrics/mAP50-95(B)']:.3f}变为{v['metrics/mAP50-95(B)']:.3f}。这是公开数据原型指标，不是摄像头识别准确率。整体改善证据不足，因此保持首版，v2只作为实验文件保存。完整测试对照见 `training-result-v2.json`。\n\n已查看两版的独立测试预测图：斧子仍误识为剑、镐子仍漏检、新的人偶头盔漏检，盔甲框还会包含头部。这些问题未解决，不能接入游戏作为已验收的识别服务。\n"
    text=f"""# 玩具风补充数据检查与训练

来源：用户提供的 `D:/数据库/`。原件未修改，5个JSON和SQLite的SHA256核验均一致，见 `原始文件核验.json`。

该文件夹提供了201条有效资源记录，按页面链接合并为184个候选。SQLite收录70条，另外三个根目录JSON有131条记录（存在重复）。原文件没有图片文件和有效YOLO框选标签；`bootstrap_labels.py` 的近乎满屏猜测框未采用。

先看 [标注预览](supplement/标注预览.jpg)，再看 [完整资源线索表](audit/资源线索.csv) 与 [模型预览核验](resolved-models/模型预览核验.json)。通过原站公开元数据核验许可的12张预览中，本轮采用9张：2张实物玩具照片、7张3D渲染。其余预览及原因保留在筛选记录中，未全部投入训练。

本批9张独立来源图片划分为训练5、验证2、测试2。保留首版683张后，v2合计692张：训练550、验证132、测试10。训练清单的936行包含稀缺样本重复抽样，不能当成936张不同照片。

装备名称保持剑、斧、镐子、弓、盔甲、头盔、护腿、靴子，不增加“玩具”前缀。数据库的greaves映射到18类中的leggings（16），helmet到15、armor到14、boots到17。类别按实际图片内容复核，例如 `thing:6590008` 的预览只有头盔，不能套用原来的armor标签。

{state}
{metrics}
此批以盔甲和头盔为主，没有新的有效斧、镐、弓照片；剑只有小尺寸实例。真实玩具图仅2张，独立新测试仅涵盖盔甲和头盔，不能宣称已完成8类玩具装备训练或能稳定连接摄像头。所有新框为AI视觉检查后放置的近似框，仍需人工验收。

分类与后续补充范围见 `玩具风分类规则.json` 和 `玩具风采集计划.csv`。模型保持实验状态，未接入游戏，也未替换首版。

可复现命令和模块说明见 `D:/aiu5/training/gifts/pipeline/toy_data/README.md`。
"""
    (ROOT/'先看这里.md').write_text(text,encoding='utf-8')
    readme="""# 玩具风数据导入与补训

`audit_database.py`只读审计输入；`resolve_models.py`核验原站许可和预览；`curate_supplement.py`保存逐图人工放置的近似部件框；`build_dataset.py`生成独立数据；`dataset_check.py`检查几何、图片、类别与分组；`training_run.py`拥有训练和对照评估；入口`train_supplement.py`仅解析配置、验证并启动，不操作游戏或摄像头。`publish_report.py`写报告和分类计划。

无需新增依赖，使用现有环境：Ultralytics 8.4.173、PyTorch 2.14.1+cu130、Pillow、PyYAML。数据和报告在`D:/AIU5-YOLO训练资料/玩具风补充/`。

```powershell
& D:/aiu2/.venv/Scripts/python.exe D:/aiu5/training/gifts/pipeline/toy_data/train_supplement.py --root D:/AIU5-YOLO训练资料/玩具风补充 --data D:/AIU5-YOLO训练资料/玩具风补充/dataset-v2 --weights D:/AIU5-YOLO训练资料/公开数据/模型交付/gifts18-prototype-v1.pt --epochs 12 --imgsz 512 --batch 8
```

再次训练由Ultralytics创建新run目录，实际输出以日志中的save_dir为准；交付文件名保留v2实验含义。现有README和统计保留首版基准，v2作为单独实验追加。更换图片后必须重新查看并修改PLAN，不能把当前框复制到其他图片。许可证、照片域、模型分组和原始URL保存在manifest中。
"""
    pipeline=PROJECT/'pipeline/toy_data';(pipeline/'README.md').write_text(readme,encoding='utf-8');shutil.copy2(Path(__file__),pipeline/'publish_report.py') if Path(__file__).resolve()!= (pipeline/'publish_report.py').resolve() else None
    catalog_path=PROJECT/'catalog.json';catalog=json.loads(catalog_path.read_text(encoding='utf-8'));catalog['appearance_guidance']=guidance
    catalog['toy_supplement']={'path':str(ROOT),'source_database':'D:/数据库','accepted_images':9,'physical_toy_photos':2,'model_renders':7,'game_integration_approved':False,'training_status':'finished' if result else 'running','experimental_model':result['delivery'] if result else None,'promotion_decision':'keep_v1' if result else 'pending_comparison'}
    catalog_path.write_text(json.dumps(catalog,ensure_ascii=False,indent=2),encoding='utf-8')
    marker='## 玩具风补充数据库'
    note=marker+'\n\n用户提供的 `D:/数据库/` 已只读审计，另存资源清单、9张初步标注图片和v2实验数据。分类名称保持不变；真实玩具照片只有2张，仍未验收摄像头效果。最新报告：`D:/AIU5-YOLO训练资料/玩具风补充/先看这里.md`。'
    append_once(PROJECT/'README.md',marker,note)
    append_once(Path('D:/AIU5-YOLO训练资料/先看这里.md'),marker,note)
    print(json.dumps({'report':str(ROOT/'先看这里.md'),'training_finished':bool(result),'source_unchanged':json.loads((ROOT/'原始文件核验.json').read_text())['all_unchanged']},ensure_ascii=False),flush=True)

if __name__=='__main__':publish()
