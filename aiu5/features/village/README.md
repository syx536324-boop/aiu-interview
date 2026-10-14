# 干旱村落与操作协调

session协调C→属性、祭台正面R觉醒与装备/技能请求，转交magic；attributes_id表示正在查看的角色，不改变selected操控者。属性/觉醒窗口阻挡移动和其他游戏键，Esc/C逐层关闭；F布置中的R继续旋转。快照attributes/awakening供UI展示，公式和装备事务留在magic，main仅负责连接。

`world.gd` / `.tscn` 构建2400×1600沙地、八间房屋、水井、猪圈、祭台、13人/3可操控/10NPC。`layout.gd` 声明居民、房屋和道路；`navigation.gd` 从逻辑障碍物生成8像素网格，初次建立后按障碍差异增减格子引用计数，`refresh_obstacles` 在圈门、资源与部署物变化后刷新路径。

`session.gd` 的 `start(world, interiors, inventory, furniture_editor, harvesting)` 初始化操作与姓名；组合入口注入生存、农田、户外部署及存档接口。会话协调角色选择、互斥C/B/F菜单、E接近互动、Q锄地、G播种/收获和背包选择种子/使用，领域规则委托对应模块。`state_changed(snapshot)` 提供HUD、角色面板、背包、布置、五项状态与每人的状态锁定标记及`crop_detail`作物阶段/成熟倒计时。死亡角色不接受选择；Tab跳过阵亡者。菜单暂停人物移动，在线计时继续。

门前E进屋、屋内下方门口E返回；室内角色不参与户外NPC互动。祭台E打开祭台菜单（赐予 / 祭台存档 / 魔法觉醒），赤沙祭台由村长兼祭司先举行祭礼，青木祭台由祭台自身行祭礼；祭台存档仍是独立回退点。人物与房间、圈门、农田、水桶、资源等均进入完整存档。姓名编辑仍委托identity校验与保存。

水源E委托homestead装满桶与木杯，背包有水的桶或杯使用委托survival；`water`布尔值仍表示有4/4满桶可灌溉，新增`water_text`呈现水量及满杯数，部分桶不会再显示成“空”。


Layout.SIZE扩大为2400×1600，旧村落坐标不变。world.extra_homes扩展可进入矿洞，pigs/cows保留动物集合。session将动物投喂、采矿和工作台交互分派给所属模块；地表河流可取水。terrain仅扫描沙路各段周边，避免扩大地图后全图×路线启动开销。M交给streaming打开独立简化全图并统一暂停，M/Esc返回。terrain按320×200分块，只准备附近区域。


## 村落类型与菜单

world.settlement决定建筑和居民集合，world.homes是当前村落实际房屋列表；starter为3屋/3可控居民，expanded为8屋/13居民，地图和全图均使用当前列表。main在_enter_tree通过save_slots/profile配置，避免先生成再删除。session.pause_requested由Esc在关闭B/C/F界面后发出，start_menu处理真正暂停；menu_paused阻止游戏输入和会话更新。祭坛交互打开储物UI；sacrifice_selected(target_id)转交altar_display/offerings执行献祭，快照包含offering目标列表与可用性。

建筑更新：construction拥有建筑台转化、动态房间与建筑生命/百分比减伤，production拥有T合成、V铁桶装沙与灶台30秒冶炼，combat拥有J弓箭及3名击败后不刷新的外部落敌人。UI通过workshop快照/操作信号请求，不计算材料与伤害；main仅组合。动态房屋/废墟加入world.homes及全图名字缓存，自建房屋附近保留3×3碰撞/敌人，远处停用；箭楼屋顶在世界坐标显示并可射箭。建筑、冶炼与敌人状态同时进入自动/祭台存档，旧档缺字段兼容。矿洞624×264保留原矿脉并新增30处铁矿，镜头跟随；详细接口和操作见新模块README与根README。

## 西岸森林接入

地图边界改用layout.BOUNDS，x=-2400..2400，SIZE仍为旧地图右下坐标(2400,1600)，MIN为(-2400,0)。navigation.rebuild(obstacles,max_corner,origin)支持负格坐标；旧坐标和出生点保持。新旧村落都包含herb_house，房屋数量分别4和9。

新增固定铁匠铺 blacksmith 与森林中部青木村：forest_herb_house、forest_chief_house、forest_wood_house、forest_stone_house 和 forest_altar。新档9间可进入建筑、6人；旧扩展档14间、16人；均仅3人可操控。FOREST_NPCS 的木长、林禾、叶青为普通NPC，继续由3×3区块流式管理。森林祭台 E 存档、R 觉醒。layout 声明位置/巡逻路线，session 只分派交互，主入口不增加业务逻辑。


武器框：画面下方偏右单格武器位，每个角色独立保存。点击空框打开背包，选镐子、斧、剑或弓后点“装备武器”；点击已装备框卸回背包（背包满则保留）。J使用已装备武器进行攻击。magic.equip_weapon负责原子物品交换及保存失败回滚，weapon_snapshot向HUD提供显示数据，session协调操作，main只连接信号。旧存档缺weapon时为空，背包内弓箭仍保留。


武器与工具更新：weapon_catalog定义镐子1、木剑1、石剑3、铁剑5、石斧2、铁斧4、弓1的基础攻击及分类。单格装备支持这些武器，equip_weapon仍原子交换并持久化。木斧从物品表移除，inventory._sanitize_slots和magic.restore_state将旧木斧转换为石斧。必须装备镐子采矿、装备斧砍树；桑树空手E采叶，持斧E砍树，其他武器不能采叶。森林树木沿用每2次1木头、4次砍完，resource_hits保持稳定ID，重载不复原。J近战29单位、0.6秒间隔、视线和朝向检查；弓每次成功发射扣背包1箭，失败不扣；X拆自建房按当前斧攻击和房屋防御计算。

## 地图翻倍与山地高原

`Layout.MIN.y` 由 0 改为 -1600、BOUNDS 变为 4800×3200：地图向北翻倍。北半部东侧是山地高原（`Layout.PLATEAU`，2400×1600，与沙漠同面积），由南缘断崖（`Layout.CLIFF`）与西侧山壁（`Layout.PLATEAU_WALL`）围合，只能靠云梯从南侧通行；高原区块由 terrain_chunk 以冷灰岩地绘制，landscape/view 画断崖与向北延伸的东部山体。相机 limit_top、顶部边界墙、terrain 分块钳制（y -8..7）、land/landscape 的 render_region 与全图投影都随之更新。

0.9.0：地图7200×6400，向南扩建而不移动旧坐标。新村落主村三创始角色及男女普通NPC各1、工作台、最低灶房、铁匠铺和圣品祭坛。旧实体栅栏亦有10HP，破坏和碰撞状态保存。场景入口只新增wildlife与tribes装配，职业/战争/婚恋业务仍在所属模块。
