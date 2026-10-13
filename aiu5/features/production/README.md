# 分类工作台与60秒制作

所有室内外工作台靠近E打开，T保留为快捷键。上方分类导航→点物品查看材料与拥有数量→右下“确认合成”；浏览不扣材料。普通工作台提供武器/工具/家具，草药屋工作台提供汤剂；铁匠炉装备合成也采用60秒。建筑台建造、武器修复以及铁矿30秒冶炼沿用原规则。

`production.gd`负责距离、配方和材料事务，`craft_queue.gd`只管理按稳定家具ID保存的任务，UI只读取快照/发perform请求。每张台同时一件，确认扣料并保存；60秒在线时间后自动送入原制作角色背包，切人不改归属。满包保留成品，回台选“领取”确认；不重复扣料。正在制作或有待领成品的台不能回收，移动保留ID与进度。任务随自动/祭台存档保存，远区/离开房间继续，M/暂停菜单/离线冻结；旧档缺craft_jobs默认为空。写入失败回滚材料和任务。

石头刀木头1＋石头1，铁刀木头1＋粗铁1，木碗木头2，剪刀木头1＋粗铁2。制作产物为普通物品，石刀攻击2／铁刀4、40格耐久、15次扣1格；未指定刀修复配方。物品分类统一读取inventory/categories.gd。

`start(session) / open_near / perform / close / elapse / snapshot / export_state / restore`为公共入口；`can_remove_fixture`供家具编辑的回收守卫。`tests/crafting_smoke.gd`覆盖真实E和鼠标、选择/确认、满包、60秒、切人、重启、全图暂停与失败回滚；smith/forest/arms/mining/construction保留材料和玩法回归。

```powershell
& 'D:\Godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path 'D:\aiu5' --script res://tests/crafting_smoke.gd
```

# 合成、装沙与冶炼

`production.gd`拥有配方、距离验证、材料事务与冶炼在线进度。工作台E/T打开分类合成；建筑台E打开四类建造；灶台T打开冶炼，E保留煎肉。UI读取snapshot并通过perform(recipe_id)请求，不计算配方。close返回；切换角色或读档关闭菜单。

建筑台木头4＋石头5（不是4组木头）；铁桶粗铁3；弓箭木头5＋粗铁2；原镐子木头1＋石头2。铁桶在沙漠空地或河岸V装满沙子（也可B选空铁桶使用），一桶占一格，不能用木水桶代替。铁屋消耗五桶内容并返还五个空铁桶，可重复使用，不产生无限桶。

灶台投入铁矿1，30在线秒后生成粗铁1；T领取后才能下一炉，不需燃料。满包保留产物；煎肉与冶炼各有自己的进度。simulation统一推进，M/菜单暂停和离线不计时，保存剩余的部分秒数。

start(session)、open_near、perform、gather_sand、elapse、snapshot、export_state/restore为公共契约。allowed与commit供construction/combat使用；提交前保存完整快照，失败恢复材料、建筑、角色位置和新模块状态。测试独立路径，不触碰玩家数据。

## 西岸森林接入

草药屋房间内工作台E/T打开herbs模式，配方归forest/catalog.gd；仍用inventory.exchange与commit原子保存，满包和失败整体回滚。汤剂60秒完成时返还空木杯；森林地面不允许用铁桶挖沙。

铁匠铺室内炉旁 E/T 冶炼，每份铁矿30在线秒生成1粗铁，需回同一炉领取。smith_smelting 与原灶房 smelting 独立，暂停/离线均不推进。furnace_state() 提供当前炉；export_state()/restore() 保留旧 remaining/ready 键，另增 blacksmith 子状态；事务仍通过 commit 保存失败回滚。UI继续读取 snapshot() 并发出 perform 请求。两个草药屋的工作台均支持汤剂。


武器与工具更新：weapon_catalog定义镐子1、木剑1、石剑3、铁剑5、石斧2、铁斧4、弓1的基础攻击及分类。单格装备支持这些武器，equip_weapon仍原子交换并持久化。木斧从物品表移除，inventory._sanitize_slots和magic.restore_state将旧木斧转换为石斧。必须装备镐子采矿、装备斧砍树；桑树空手E采叶，持斧E砍树，其他武器不能采叶。森林树木沿用每2次1木头、4次砍完，resource_hits保持稳定ID，重载不复原。J近战29单位、0.6秒间隔、视线和朝向检查；弓每次成功发射扣背包1箭，失败不扣；X拆自建房按当前斧攻击和房屋防御计算。

工作台E分类配方（选择后确认，制作60秒）：石斧/石剑=木头1+石头2；木剑=木头3；铁斧/铁剑=木头1+粗铁2；箭×10=木头2+粗铁1。镐子和弓沿用原配方。

## 铁匠铺修复与装备

炉旁smelt模式在blacksmith房间附加repairs.options(session)与smith_catalog.RECIPES。perform的repair:equipped/repair:bag:N选择实际损坏实例，石制（含镐子）用石头1，铁制用粗铁1，恢复40/0；只在同一炉旁允许，木剑/弓和未损坏物品拒绝。背包exchange后重新获取目标格，避免修改旧字典。smith:前缀配方为皮革/粗铁8盔甲、5护腿、4头盔、4靴，当前背包扣料，60秒完成出物。均复用commit整体回滚；厨房炉和普通工作台不提供这些入口。smith_smoke验证全配方、同款精确修复、满包、失败与快照恢复。

## 0.6规则

工作台新增锄头、浇水壶、水桶、木杯、工作台、围栏、面包、床、柜、桌、椅、箱；成品均需60在线秒。石头刀=木1石1，铁刀=木1粗铁1；碗=木2，剪刀=木1粗铁2。皮/铁装备分别用皮革/粗铁，盔甲8、护腿5、头盔4、靴4。斧剑沿用现有材料。书本没有配方，只能摄像头赐予。

## 魔法分支接入（0.8.0）

open_upgrade由U打开自建房升级，所有配方与进度取construction.upgrade_snapshot；perform转交upgrade_near。旺炉作用范围内、非战斗时实际冶炼速度乘1.4；材料和成品仍走原保存事务。

## 0.8.1接口与规则

scissors_tools通过available／options／perform／advance提供普通剪刀采集与裁剪。production.open_scissors仅打开采集页，UI使用snapshot与perform请求；牛皮1→皮革2，羊毛2每成年羊300在线秒，藤条1每森林草丛120在线秒；export_state／restore保存冷却。cloth配方silk5→cloth1、60在线秒；床追加cloth5。
