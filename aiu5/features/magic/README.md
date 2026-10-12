# 魔法属性、升级、装备与技能

`catalog.gd` 定义木/水/火/土、1–100级费用、四个装备部位与五个主干节点。`progression.gd` 以稳定角色ID持有状态，没有逐帧或离线模拟；魔法等级/经验/技能点与survival的当前魔力与恢复计时是独立数据。

祭台正面R打开四系选择，确认后永久觉醒其中之一；起始lv.1、0技能点；此前累计的击杀/成就魔法点在觉醒时一次结算。只有当前存活角色在祭台前可觉醒，E继续负责祭台存档/祭礼。C→对应角色“属性”可以查看其他角色而不切换操控，阵亡角色只读。

当前等级1–9升一级需100魔法点，10–19需200，20–29需300，以此类推，90–99需1000；lv.100封顶。经验可跨级结算，每升一级+5技能点，满级进度条显示已满。初始一级不赠点，1→100共54,900魔法点、495技能点。每个主干消耗10点且必须依次点亮，不可重复消费；主干完成后显示三条分支入口，数量与效果待补充，不开放未定义技能。

头部/盔甲/护腿/靴子槽分别接受对应的皮制或铁制装备，材料数量见inventory/catalog.gd与production/smith_catalog.gd；不提供免费领取。穿戴从该角色自己的背包移出，卸下返还同一背包；容量不足保留原装备。装备暂不提供数值加成，不修改角色行走图像。

公共接口：`start(session)`连接会话；`awaken(id, element)`、`award_points(id, amount)`、`unlock(id, skill)`、`claim_gear(id)`、`equip(id, slot, item)`返回bool；`snapshot(id)`提供显示数据；`export_state()`/`restore(data)`处理持久化。`message`发出操作结果。击杀获得25魔法点，已定义成就每项100点；未觉醒先累计，事件通过credit_points与实际动作同次提交。五级技能名称、费用和效果由skill_catalog定义；skills执行动作、效果计时与存档，skill_visual显示效果。详细规则见../../docs/ELEMENTAL_SKILLS.md。

所有修改在规则/容量校验后立即自动保存，失败撤销魔法数据与背包；暂停、阵亡、读档过程中禁止修改。单人献祭复活保留属性/经验/装备；全员阵亡或主动祭台回退恢复完整快照。旧档无magic字段时默认未觉醒、lv.1、空装备，不改变已有物品。

入口由`scenes/main.gd`组合；interface/attributes仅展示session快照并发出动作信号，session转交本模块。验证见`tests/magic_smoke.gd`及slot_quit_save双进程，覆盖升级边界、真实UI、互斥选择、满包保护、保存失败、复活、续玩和旧档。

awakening_error 同时验证赤沙祭台和青木祭台的距离，仍只允许当前存活可操控角色觉醒。


武器框：画面下方偏右单格武器位，每个角色独立保存。点击空框打开背包，选镐子、斧、剑或弓后点“装备武器”；点击已装备框卸回背包（背包满则保留）。J使用已装备武器进行攻击。magic.equip_weapon负责原子物品交换及保存失败回滚，weapon_snapshot向HUD提供显示数据，session协调操作，main只连接信号。旧存档缺weapon时为空，背包内弓箭仍保留。


武器与工具更新：weapon_catalog定义镐子1、木剑1、石剑3、铁剑5、石斧2、铁斧4、弓10的基础攻击及分类。单格装备支持这些武器，equip_weapon仍原子交换并持久化。木斧从物品表移除，inventory._sanitize_slots和magic.restore_state将旧木斧转换为石斧。必须装备镐子采矿、装备斧砍树；桑树空手E采叶，持斧E砍树，其他武器不能采叶。森林树木沿用每2次1木头、4次砍完，resource_hits保持稳定ID，重载不复原。J近战29单位、0.6秒间隔、视线和朝向检查；弓每次成功发射扣背包1箭，失败不扣；X拆自建房按当前斧攻击和房屋防御计算。

## 单件武器耐久

每位角色的equipment.weapon配套weapon_wear={durability:40,uses:0}；旧存档缺失时补满。equip_weapon(id,item,bag_index=-1)通过inventory.swap_weapon交换实际单件记录，可指定同款中的某一格。weapon_usable检查损坏；consume_weapon只改内存，调用方须与实际动作一起提交或回滚。weapon_snapshot提供wear和durability_text，不在UI中计算扣除。祭台和退出快照均包含此状态。

## 装备材质

equipment_catalog.SLOTS定义皮制、铁制装备与四个部位的兼容表；equip仍验证部位并原子交换当前角色背包，restore_state保留具体材质ID，旧基础装备兼容。snapshot每格提供choices与equipped_name，UI选择具体ID后请求穿戴，数值效果仍未设置。武器耐久独立于防具材质。

## 经验来源

击杀每只生物25魔法点；成就每项每角色一次100点，具体成就待定。未觉醒时pending_points持久累计，觉醒时一次结算；credit_points只改变状态，调用者与事件一起原子保存。取消免费基础装备领取，只提供皮制与铁制。魔力生命值与魔法经验保持独立。

## 元素技能执行

skills.cast(rank, target)验证当前角色、目标和魔力，成功后与实际动作共同保存；失败回滚。一级被动由survival应用，二级赋能独立于武器魔法属性，三至五级使用H/K/L。simulation以在线时间推进，暂停和离线不消耗效果；export_state/restore保留buff、火球、敌人状态和临时土屋。旧六节点保留前五级并仅一次退还第六级10技能点。魔力初始10点，上限为10＋（魔法等级－1）×5；每升一级上限增加5点，升级不直接补充当前魔力。当前操控的存活角色每60在线秒恢复1点，满值停止累计；暂停、离线、阵亡和未操控角色不推进恢复，切换与保存保留未满一分钟的进度。旧存档保留当前魔力，缺少恢复计时默认为0。。elemental_smoke覆盖实际效果、计时边界、存档及失败回滚。
