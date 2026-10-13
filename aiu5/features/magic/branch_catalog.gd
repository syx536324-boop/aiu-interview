# Defines all thirty-six branch skills, prerequisites and confirmed gameplay parameters.
extends RefCounted
const LEVELS := [12,20,30]
const POINTS := [15,25,40]
const MANA := [40,65,95]
const BRANCHES := {"build":"建设","battle":"战斗","guard":"防御"}
const ELEMENTS := ["wood","water","fire","earth"]
const DATA := {
	"wood":{
		"build":[["生命树","半径80世界像素；生命、魔力每5秒＋1，持续10分钟；战斗中不可施放或恢复。"],["魔力草丛","生成永久草丛，每120秒人参、灵芝、枸杞各18%刷新一份；未采走不累积。"],["速建","立即完成120像素内一项已支付材料的房屋建设或升级。"]],
		"battle":[["藤缚","单体定身2秒并造成2伤害。"],["棘雨","前方60°、140像素内最多4目标各6伤害，减速30%持续3秒。"],["绞杀","单体持续6秒，每秒3伤害，减速50%；不同技能减速叠加封顶60%。"]],
		"guard":[["树皮","10秒减伤25%。"],["根须护体","12秒减伤40%，免疫击退。"],["生命之泉","自身恢复30%生命，100像素内同伴恢复15%；冷却60秒。"]]},
	"water":{
		"build":[["灵泉","半径80像素，10分钟；生命每10秒＋1，魔力及饥渴每5秒＋1；战斗中停止。"],["引水","生成60像素水渠，旁边农田30秒免浇灌。"],["水车","120像素内一项施工20秒进度速度＋50%。"]],
		"battle":[["水弹","单体8伤害，击退20像素。"],["寒潮","120像素内最多5目标各5伤害，减速40%持续4秒。"],["冰封","单体冻结3秒，随后减速30%持续5秒；冷却25秒。"]],
		"guard":[["水膜","20点护盾，持续15秒。"],["净流","解除流血、中毒、点燃，并恢复15%生命。"],["潮汐之护","60点护盾持续12秒，远程减伤30%。"]]},
	"fire":{
		"build":[["旺炉","半径80像素，10分钟；魔力每5秒＋1，生命与饥饿每10秒＋1；烹饪／冶炼＋40%。战斗中停止。"],["熔接","立即推进120像素内当前建筑总进度的30%，箭楼除外。"],["地火窖","生成96×80地火区域，持续30秒；敌人留在其中每3秒扣4生命。"]],
		"battle":[["火球","单体10伤害并点燃3秒，每秒2伤害。"],["燃爆","110像素内敌人各8伤害，点燃4秒每秒2伤害；自身反噬2。"],["焚风","前方180×80喷流，12伤害并点燃6秒每秒2伤害；对建筑伤害＋50%。"]],
		"guard":[["火障","身前火墙持续6秒，敌人每秒3伤害并减速20%。"],["炽壳","10秒近战减伤40%，反弹实际受到伤害的25%。"],["余烬","预先施放护身，下一次致死伤害留1生命并恢复40%；触发后冷却5分钟。"]]},
	"earth":{
		"build":[["地脉祭坛","半径80世界像素，每5秒恢复1魔力，持续10分钟；战斗中不可施放或恢复。"],["勘测","30秒标出200像素内矿脉与采集点。"],["石阵","3×3田格范围，生命200／防御20，持续60秒；普通减伤后额外减10%，总免伤最高55%。"]],
		"battle":[["投石","单体9伤害，击退30像素。"],["碎地","100像素内敌人各10伤害并定身2秒。"],["石化","单体4秒不能行动，累计受到20伤害提前解除。"]],
		"guard":[["石肤","12秒减伤20%。"],["壁垒","身前120×30石壁，持续10秒，阻挡远程攻击。"],["大地之拥","8秒减伤50%、免疫控制，期间自己不能移动。"]]}}
static func skill_id(element: String, branch: String, rank: int) -> String:
	return "%s_%s_%d" % [element,branch,rank]
static func entry(id: String) -> Dictionary:
	var parts := id.split("_")
	if parts.size()!=3 or not DATA.has(parts[0]) or not BRANCHES.has(parts[1]): return {}
	var rank := int(parts[2])
	if rank<1 or rank>3 or parts[2]!=str(rank): return {}
	var row: Array=DATA[parts[0]][parts[1]][rank-1]
	var cooldown := 3.0 if rank==1 else (12.0 if rank==2 else 20.0)
	if id=="wood_guard_3": cooldown=60.0
	if id=="water_battle_3": cooldown=25.0
	return {"id":id,"element":parts[0],"branch":parts[1],"branch_name":BRANCHES[parts[1]],"rank":rank,"name":row[0],"description":row[1],"level":LEVELS[rank-1],"points":POINTS[rank-1],"mana_cost":MANA[rank-1],"cooldown":cooldown}
static func entries(element: String) -> Array:
	var result: Array=[]
	if not DATA.has(element): return result
	for branch: String in BRANCHES:
		for rank in range(1,4): result.append(entry(skill_id(element,branch,rank)))
	return result
static func unlock_error(state: Dictionary, id: String) -> String:
	var rule := entry(id)
	if rule.is_empty() or state.element!=rule.element: return "请选择已觉醒属性的分支技能。"
	if state.unlocked.size()<5: return "依次点亮五个主干技能后，才能学习分支。"
	if state.get("branch_unlocked",[]).has(id): return "该分支技能已点亮。"
	if int(state.level)<int(rule.level): return "该技能需要魔法等级%d。" % int(rule.level)
	if rule.rank>1 and not state.get("branch_unlocked",[]).has(skill_id(rule.element,rule.branch,rule.rank-1)): return "先点亮本分支的上一阶。"
	if int(state.skill_points)<int(rule.points): return "技能点不足，需要%d点。" % int(rule.points)
	return ""
