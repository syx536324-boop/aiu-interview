# 沙盘上的生活

Godot 4.7.2 Windows 村落生存游戏，当前本地版本 **0.9.0**。每24真实分钟为一天；暂停、全图、离线不推进经营计时。

## 安装与运行

双击 `exports/AIU5-Setup-0.9.0-win64.exe`，从开始菜单“沙盘上的生活”启动。安装器随附本地摄像头识别环境，升级不改动玩家存档。正式已发布版本见 [aiu-interview Releases](https://github.com/syx536324-boop/aiu-interview/releases)。

源码启动：

```powershell
Godot_v4.7.2-stable_win64_console.exe --path D:\aiu5
```

构建：

```powershell
pwsh -File packaging/windows/build.ps1 -Godot 'C:\tools\Godot.exe' -ISCC 'C:\tools\Inno Setup\ISCC.exe'
```

源码须配套 `models`、`runtime` 与导出模板，详见 [Windows交付说明](packaging/windows/README.md)。存档继续使用 `%APPDATA%\Godot\app_userdata\AIU5 · 赤沙村`。

## 当前玩法

- 新村落有三名创始可控角色、两名普通NPC（一男一女）、一个工作台、最低灶房、铁匠铺与圣品祭坛。背包两种种子各3，工具靠制作。历史存档保留已建设施和物品。
- 地图7200×6400，原坐标不动；森林增加河流支流和不可砍巨树。全图黑暗隐藏人物与地点名，点亮30秒后再次隐藏；手动永久标记的矿洞例外。
- 野生牛猪羊按256×256区块首次30%概率生成1～2只，合计最多2，不补刷。工作台布3做绳1，角色合计最多两条；木4做栅栏门1，门E开关，围栏及门生命10可破坏。
- 三外部落初始20人含村长，按创始角色最高魔法等级逐级增员，最高30，不补活死者。5级起按已确认规则轮流最多4人进犯。村长可出征、召回；NPC职业升级、9格背包、农务与有限采矿独立运行。
- 圣品生命200，击毁敌村圣品可占领、归附幸存成员。重建5在线分钟生成同属性可控村长；分村失守可重新占领，只有主村圣品被毁清当前村落档及回退点。
- 建筑台木50石30建设草药屋，30在线秒。有草药屋后，成年异性好感80可选有床普通婚房结婚，允许多名配偶，每对分别保存婚房。面包1好感＋5，初50上限100。婚床红帘后孕期10分钟，接生窗口2分钟；NPC自动去草药屋。幼童5分钟成年，超时流产扣最大生命99%。
- 每种物品首次取得奖励25魔法点，击杀亦25；魔力上限10＋（等级－1）×5，基础每60在线秒回1。四系主干5级及36分支、晶石房屋升级、同来源互斥、减速60%／减伤55%上限保留。
- 石刀2、铁刀4；镐／斧／剑30世界像素·1秒，刀20·0.4秒，弓150·1秒（高地×0.7）。火把80×80、篝火96×96世界像素照明。赐予武器保存赐予时等级，12级起选择四属性。

E互动，B背包，F部署，Q耕地，G播种/收获，J或右键攻击，T制作/冶炼，C属性，Z/H/K/L主干，P分支，U房屋升级，M全图，Esc暂停。

NPC间婚礼由玩家主持：E互动→主持NPC婚礼→选本方成年异性→选有床普通婚房，免好感门槛，面包16平分各8。双方自动进婚房、怀孕、接生一次；后续E发起再次生育。村庄仍须已有草药屋。

完整规则：[游戏玩法介绍](游戏玩法介绍.md)、[全部80种物品来源](docs/ITEM_SOURCES.md)、[部落与婚恋](docs/TRIBES_ROMANCE_0.9.0.md)、[魔法分支](docs/ELEMENTAL_BRANCHES.md)、[武器与附魔](docs/WEAPONS_EQUIPMENT_0.8.1.md)。

## 模块与验证

`scenes/main.gd`只装配。`features/tribes`负责职业、工作、战争、圣品与定居点；`features/romance`负责关系、NPC婚礼、生育与红帘；`features/livestock`负责牲畜与牵绳。UI读取快照并发送动作，材料、伤害和计时归业务模块。各功能目录README记录接口。

隔离验证见 [0.9.0记录](docs/TRIBES_ROMANCE_0.9.0.md)。运行场景前设置 `AIU5_PROBE_DIRECTORY` 为新的测试目录，不使用真实玩家档：

```powershell
$env:AIU5_PROBE_DIRECTORY='C:\temp\aiu5-090-check'
Godot_v4.7.2-stable_win64_console.exe --headless --path D:\aiu5 res://tests/tribes_final_probe.tscn
```

第三方资源见 [资源声明](THIRD_PARTY_NOTICES.md)。摄像头18类首版模型的实物准确率仍需逐类验收。
