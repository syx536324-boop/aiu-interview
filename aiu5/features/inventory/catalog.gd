# Defines the initial item types, stack limits and starter equipment.
extends RefCounted

const Water := preload("res://features/inventory/water_catalog.gd")

# Items a new character already owns. They are a starting grant, not a first discovery,
# so achievements only fire once the character genuinely holds more than this amount.
const STARTING := {"seeds":3, "rice_seeds":3}

const ITEMS := {
	"rope":{"name":"绳子","limit":99,"use_label":"查看牵绳","description":"工作台：布3→绳子1，60在线秒。靠近牛、猪、羊按E绑上，每根对应一只；全部角色合计最多同时两根。解开返还绳子。"},
	"fence_gate":{"name":"栅栏门","limit":99,"use_label":"部署栅栏门","description":"工作台：木头4→栅栏门1，60在线秒。F部署，靠近按E开关；生命10，可被武器摧毁。"},
	"iron_pickaxe":{"name":"铁镐","limit":1,"use_label":"装备武器","description":"工作台：木头1＋粗铁2，60在线秒。可采矿，攻击2、范围30世界像素、间隔1秒；用于矿工5级升级。"},
	"magic_scissors":{"name":"魔法剪刀","limit":1,"use_label":"装备武器","description":"仅摄像头赐予剪刀可得；基础攻击3＋min(赐予等级×0.2,10)，射程80世界像素。距离不足40时0.5秒一次；40及以上1秒一次，飞出命中后自动飞回。需视线无遮挡，可在12级选择四系属性。"},
	"cowhide":{"name":"牛皮","limit":99,"description":"击杀牛获得1张，与牛肉一起掉落；背包选剪刀可将牛皮1裁成皮革2。"},
	"silk":{"name":"蚕丝","limit":99,"description":"空手采桑叶时30%概率额外得到1份；工作台5蚕丝制作1布。"},
	"cloth":{"name":"布","limit":99,"description":"工作台：蚕丝5→布1，60在线秒；制作床需布5、羊毛4、木头4。"},
	"vine":{"name":"藤条","limit":99,"description":"随身剪刀在森林草丛旁使用，每片草丛每120在线秒可剪1份，与种子刷新独立；其他用途待定。"},
	"wood_crystal":{"name":"木系魔法晶石","limit":99,"description":"木系魔法等级每到5的倍数获得一颗；旧角色补发，满包在属性页待领。房屋升到4／6／8／10级可选用1颗，永久增加房屋木属性免伤2%。"},
	"water_crystal":{"name":"水系魔法晶石","limit":99,"description":"水系魔法等级每到5的倍数获得一颗；房屋偶数等级4级起升级可用，累计每颗增加水属性免伤2%。"},
	"fire_crystal":{"name":"火系魔法晶石","limit":99,"description":"火系魔法等级每到5的倍数获得一颗；房屋偶数等级4级起升级可用，累计每颗增加火属性免伤2%。"},
	"earth_crystal":{"name":"土系魔法晶石","limit":99,"description":"土系魔法等级每到5的倍数获得一颗；房屋偶数等级4级起升级可用，累计每颗增加土属性免伤2%。"},
	"torch":{"name":"火把","limit":1,"description":"工作台：煤矿1＋木头1，制作60在线秒。装备独立火把格，点燃后照亮80×80世界像素。累计燃烧10分钟报废，每次燃烧5分钟熄灭；点亮篝火旁E或火系三级H点燃。","use_label":"装备火把"},
	"campfire":{"name":"篝火","limit":1,"description":"工作台：石头2＋木头1＋煤矿1，制作60秒。B选中后部署；E点亮/熄灭，火系H可瞬间点亮。照明96×96世界像素。","use_label":"部署篝火"},
	"coal":{"name":"煤矿","limit":99,"description":"扩建矿洞按保存种子生成，每区块40%概率有煤矿脉；装备镐子采集3次获得煤矿3个。篝火合成需要煤矿1。"},
	"iron_knife":{"name":"铁刀","limit":1,"description":"工作台：木头1＋粗铁1，60在线秒。攻击4，沿用刀的耐久规则。","use_label":"装备武器"},
	"beef":{"name":"生牛肉","limit":99,"description":"击杀牛获得1份；灶台E烹饪60在线秒，灶台旁B选中使用可指定烹饪。生食规则同生猪肉。","use_label":"食用 / 灶台烹饪"},
	"mutton":{"name":"生羊肉","limit":99,"description":"击杀成年羊获得1份；灶台E烹饪60在线秒，灶台旁B选中使用可指定烹饪。生食规则同生猪肉。","use_label":"食用 / 灶台烹饪"},
	"cooked_beef":{"name":"熟牛肉","limit":99,"description":"灶台生牛肉1→熟牛肉1，60在线秒；食用饥饿+4、健康+1。","use_label":"食用"},
	"cooked_mutton":{"name":"熟羊肉","limit":99,"description":"灶台生羊肉1→熟羊肉1，60在线秒；食用饥饿+4、健康+1。","use_label":"食用"},
	"wool":{"name":"羊毛","limit":99,"description":"普通剪刀每只成年羊每300在线秒剪羊毛2块；击杀成年羊也获得2块；工作台羊毛4＋木头4＋布5合成床。"},
	"cabinet":{"name":"柜子","limit":20,"description":"工作台：木头5，60在线秒。屋内F部署，21格储物，取空后回收。","use_label":"部署柜子"},
	"table":{"name":"桌子","limit":20,"description":"工作台：木头4，60在线秒。屋内F部署，回收返还成品。","use_label":"部署桌子"},
	"chair":{"name":"椅子","limit":20,"description":"工作台：木头4，60在线秒。屋内F部署，回收返还成品。","use_label":"部署椅子"},
	"chest":{"name":"箱子","limit":20,"description":"工作台：木头5，60在线秒。屋内F部署，21格储物，取空后回收。","use_label":"部署箱子"},
	"bed":{"name":"床","limit":1,"description":"工作台：羊毛4＋木头4＋布5，60在线秒；也可摄像头赐予。屋内F部署，回收保留物品来源。","use_label":"部署床"},
	"knife":{"name":"石头刀","limit":1,"description":"石头刀；工作台：木头1＋石头1，60在线秒。攻击2，可装备；摄像头识别刀赐予石头刀。","use_label":"装备武器"},
	"bowl":{"name":"碗","limit":20,"description":"工作台：木头2，60在线秒。普通木碗，暂不增加烹饪规则；也可摄像头赐予。"},
	"scissors":{"name":"剪刀","limit":1,"description":"工作台：木头1＋粗铁2，60在线秒。采集工具：背包选中使用，可剪成年羊毛、森林藤条或裁牛皮1→皮革2。","use_label":"使用剪刀"},
	"apple":{"name":"苹果","limit":99,"description":"祭台摄像头赐予；食用恢复饥饿2格。","use_label":"食用苹果"},
	"carrot":{"name":"胡萝卜","limit":99,"description":"祭台摄像头赐予；食用恢复饥饿2格。","use_label":"食用胡萝卜"},
	"leather": {"name":"皮革","limit":99,"description":"牛皮1用剪刀裁成皮革2；铁匠铺合成皮制装备。"},
	"leather_armor": {"name":"皮盔甲","limit":1,"description":"铁匠铺：8份皮革；C→属性中穿戴。防御1，免伤5%；四件皮装备合计20%。","use_label":"打开装备页"},
	"leather_leggings": {"name":"皮护腿","limit":1,"description":"铁匠铺：5份皮革；C→属性中穿戴。防御1，免伤5%；四件皮装备合计20%。","use_label":"打开装备页"},
	"leather_helmet": {"name":"皮头盔","limit":1,"description":"铁匠铺：4份皮革；C→属性中穿戴。防御1，免伤5%；四件皮装备合计20%。","use_label":"打开装备页"},
	"leather_boots": {"name":"皮靴","limit":1,"description":"铁匠铺：4份皮革；C→属性中穿戴。防御1，免伤5%；四件皮装备合计20%。","use_label":"打开装备页"},
	"iron_armor": {"name":"铁盔甲","limit":1,"description":"铁匠铺：8份粗铁；C→属性中穿戴。防御3，免伤15%；满套铁装备合计40%，普通总减伤封顶50%。","use_label":"打开装备页"},
	"iron_leggings": {"name":"铁护腿","limit":1,"description":"铁匠铺：5份粗铁；C→属性中穿戴。防御2，免伤10%；满套铁装备合计40%，普通总减伤封顶50%。","use_label":"打开装备页"},
	"iron_helmet": {"name":"铁头盔","limit":1,"description":"铁匠铺：4份粗铁；C→属性中穿戴。防御2，免伤10%；满套铁装备合计40%，普通总减伤封顶50%。","use_label":"打开装备页"},
	"iron_boots": {"name":"铁靴","limit":1,"description":"铁匠铺：4份粗铁；C→属性中穿戴。防御1，免伤5%；满套铁装备合计40%，普通总减伤封顶50%。","use_label":"打开装备页"},

	"ginseng": {"name":"人参","limit":99,"description":"西岸森林采集；人参1＋灵芝1＋一杯水在草药屋合成大补汤。"},
	"reishi": {"name":"灵芝","limit":99,"description":"西岸森林采集；用于草药屋的大补汤配方。"},
	"goji": {"name":"枸杞","limit":99,"description":"西岸森林采集；枸杞1＋桑叶1＋一杯水在草药屋合成补气汤。"},
	"mulberry_leaf": {"name":"桑叶","limit":99,"description":"空手在桑树旁E采集，30%概率额外获得蚕丝1；树木保留；持斧E砍树，2分钟在线时间后恢复。"},
	"restorative_soup": {"name":"大补汤","limit":99,"use_label":"喝汤","description":"草药屋：人参1＋灵芝1＋满水木杯1，60在线秒，返还空杯。饮用使生命和健康回满至10。"},
	"qi_soup": {"name":"补气汤","limit":99,"use_label":"喝汤","description":"草药屋：枸杞1＋桑叶1＋满水木杯1，60在线秒，返还空杯。饮用健康+5、生命+3，上限10。"},
	"building_bench": {"name":"建筑台","limit":20,"description":"工作台E：木头4＋石头5。仅可F部署到户外，预留96×80建筑用地；靠近E建造。","use_label":"部署建筑台"},
	"iron_bucket": {"name":"铁桶","limit":1,"description":"工作台E：粗铁3。在沙漠空地或河岸按V装沙。","use_label":"装沙"},
	"sand_bucket": {"name":"一桶沙子","limit":1,"description":"携带空铁桶在沙漠空地或河东岸V装沙；高级铁屋需5桶，建造后返还空铁桶。"},
	"crude_iron": {"name":"粗铁","limit":99,"description":"灶台T投入铁矿，30在线秒炼成1粗铁，用于铁桶、弓箭和铁屋。"},
	"bow": {"name":"弓","limit":1,"description":"工作台E：木头5＋粗铁2。背包装备到武器格后，鼠标瞄准、J发射，基础伤害1/1秒；每次发射消耗背包1支箭。","use_label":"装备武器"},
	"pickaxe": {"name": "镐子", "limit": 1, "description": "攻击1；必须装备后在矿脉旁E采集。工作台：木头1＋石头2。", "use_label": "装备武器"},
	"hoe": {"name": "锄头", "limit": 1, "description": "工作台：木头2＋石头1，60在线秒。携带后户外Q开垦农田。"},
	"stone_axe": {"name":"石斧","limit":1,"description":"工作台：木头1＋石头2。攻击2；装备后E砍树，J近战。制作需60在线秒。","use_label":"装备武器"},
	"iron_axe": {"name":"铁斧","limit":1,"description":"工作台：木头1＋粗铁2。攻击4；装备后E砍树，J近战。制作需60在线秒。","use_label":"装备武器"},
	"wood_sword": {"name":"木剑","limit":1,"description":"工作台：木头3。攻击1；装备后J近战。制作需60在线秒。","use_label":"装备武器"},
	"stone_sword": {"name":"石剑","limit":1,"description":"工作台：木头1＋石头2。攻击3；装备后J近战。制作需60在线秒。","use_label":"装备武器"},
	"iron_sword": {"name":"铁剑","limit":1,"description":"工作台：木头1＋粗铁2。攻击5；装备后J近战。制作需60在线秒。","use_label":"装备武器"},
	"arrow": {"name":"箭","limit":99,"description":"工作台：木头2＋粗铁1制作10支。装备弓每次发射消耗背包中1支箭。"},
	"watering_can": {"name": "水壶", "limit": 1, "description": "工作台：木头2，60在线秒。浇水壶；当前农田灌溉仍使用4/4满水桶。"},
	"bread": {"name": "面包", "limit": 99, "description": "工作台：小麦3，60在线秒。食用恢复饥饿3格。"},
	"book": {"name": "书本", "limit": 10, "description": "只能由祭台摄像头赐予；阅读玩法待定义。"},
	"pork": {"name": "生猪肉", "limit": 99, "use_label":"食用 / 灶台烹饪","description": "击杀猪获得1份。灶台E烹饪60在线秒；灶台旁B选中使用可指定烹饪。生食饥饿+2，10分钟吃3次生肉会引发肠胃炎。"},
	"bucket": {"name": "水桶", "limit": 1, "description": "工作台：木头3，60在线秒。水源旁E装满；满桶可灌溉，喝水与灌溉后保留容器。"},
	"water_bucket": {"name": "满水桶", "limit": 1, "use_label": "饮水（1/4桶）", "description": "水源旁E装满空/部分水桶得到，水量4/4；每次喝1/4桶，饥渴+4；只有满桶可灌溉，灌溉用完整桶。"},
	"water_bucket_3": {"name": "水桶3/4", "limit": 1, "use_label": "饮水（1/4桶）", "description": "剩余3/4桶；每次饮水饥渴+4。不能灌溉，水井或湖边 E 补满。"},
	"water_bucket_2": {"name": "水桶2/4", "limit": 1, "use_label": "饮水（1/4桶）", "description": "剩余2/4桶；每次饮水饥渴+4。不能灌溉，水井或湖边 E 补满。"},
	"water_bucket_1": {"name": "水桶1/4", "limit": 1, "use_label": "饮水（1/4桶）", "description": "剩余1/4桶；喝完饥渴+4并留下空桶。不能灌溉，水源旁 E 补满。"},
	"wooden_cup": {"name": "木质水杯", "limit": 1, "description": "工作台：木头1，60在线秒；也可摄像头赐予。水源旁E装满，饮水或合成汤后保留空杯。"},
	"water_cup": {"name": "满水木杯", "limit": 1, "use_label": "饮水（一杯）", "description": "装满水的木质水杯；一次喝一杯，饥渴+4并留下空杯，可重新装水。不能灌溉。"},
	"cooked_pork": {"name": "熟猪肉", "limit": 99, "description": "灶台E投入生猪肉1，60在线秒后E领取1份。食用饥饿+4、健康+1，健康达到7解除肠胃炎。"},
	"workbench": {"name": "工作台", "limit": 20, "description": "公共工作台或已有工作台：木头3＋石头1，60在线秒。F部署，靠近E打开合成；回收返还成品。"},
	"fence": {"name": "围栏", "limit": 99, "description": "工作台：木头4→围栏1，60在线秒。F部署，回收返还；生命10，可被武器摧毁；可配合栅栏门围养牲畜。"},
	"seeds": {"name": "小麦种子", "limit": 99, "use_label": "选择种子 / 播种", "description": "新角色初始3个；森林草丛每2在线分钟20%概率生成一种种子。湿润空田G播种，8分钟成熟，收获小麦1＋种子2。"},
	"rice_seeds": {"name": "水稻种子", "limit": 99, "use_label": "选择种子 / 播种", "description": "新角色初始3个；森林草丛每2在线分钟20%概率生成一种种子。湿润空田G播种，8分钟成熟，收获稻谷1＋种子2。"},
	"wheat": {"name": "小麦", "limit": 99, "description": "小麦种子在湿润空田G播种，8在线分钟成熟，G收获小麦1＋种子2。工作台3小麦做面包；亦可喂动物。", "use_label": "喂动物（1份）"},
	"rice": {"name": "稻谷", "limit": 99, "description": "水稻种子在湿润空田G播种，8在线分钟成熟，G收获稻谷1＋种子2；亦可喂动物。", "use_label": "喂动物（1份）"},
	"stone": {"name": "石头", "limit": 99, "description": "装备镐子采石矿获得；村里地表散落石头可空手E拾取。用于工作台制作。"},
	"iron_ore": {"name": "铁矿", "limit": 99, "description": "地下采得的原矿；灶台旁T冶炼，铁矿1→粗铁1，需30在线秒。"},
	"wood": {"name": "木头", "limit": 99, "description": "装备斧头砍树获得；村里地表散落树枝可空手E拾取。用于工作台制作。"}
}
const LEGACY_GEAR := {"armor":"leather_armor","leggings":"leather_leggings","hood":"leather_helmet","boots":"leather_boots"}

static func canonical(item: String) -> String:
	return str(LEGACY_GEAR.get(item,item))

const STARTER_IDS := []

static func starter_slots() -> Array:
	var slots: Array = []
	for id: String in STARTER_IDS:
		slots.append({"item": id, "count": 5 if id == "bread" else (3 if id == "pork" else 1)})
	while slots.size() < 21:
		slots.append({})
	return slots
