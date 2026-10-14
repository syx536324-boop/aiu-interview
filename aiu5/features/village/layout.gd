# Declares settlement size, housing, roads and resident records without gameplay behavior.
extends RefCounted

const SIZE := Vector2(4800, 4800)
# World bounds are x=-2400..4800 and y=-1600..4800: 7200x6400, preserving all older coordinates.
const MIN := Vector2(-2400, -1600)
const BOUNDS := Rect2(MIN, SIZE - MIN)
const FOREST := Rect2(-2400, 0, 2400, 4800)
# The woodland continues north of the original map, with the same gatherable mix.
const FOREST_NORTH := Rect2(-2400, -1600, 2400, 1600)
# Mountain plateau: the north-east quadrant above the desert, reached from the desert floor.
const PLATEAU := Rect2(0, -1600, 2400, 1600)
# The starting village is always visible on the overview map, even before it is re-explored.
const HOME_LIT := Rect2(40, 0, 940, 660)
# Southern cliff of the plateau; only a deployed cloud ladder opens a way through it.
const CLIFF := Rect2(-40, -30, 2480, 30)
# Western escarpment of the plateau: the highland is otherwise unreachable on foot.
const PLATEAU_WALL := Rect2(-8, -1600, 16, 1570)
# Eastern extension: a mountain zone east of the old border, with the Yunye tribe on its mid-slope.
const MOUNTAINS_EAST := Rect2(2400, -1600, 2400, 6400)
# North-south ridge sealing the mountains off; a second cloud ladder opens a pass through it.
const RIDGE := Rect2(2400, -1600, 30, 3200)
# Yunye tribe territory on the mountainside (山腰).
const YUNYE := Rect2(2850, -1050, 900, 700)
const FOREST_VILLAGE := Rect2(-1400,640,400,340)
const FOREST_PLAZA := Rect2(-1250,756,100,80)
const FOREST_ALTAR := Vector2(-1200,790)
const HOMES := [
	{"id":"blacksmith", "name":"铁匠铺", "atlas":"desert", "region":Rect2(96,0,64,48), "at":Vector2(792,220), "body":Vector2(52,27), "door":Vector2(824,274), "description":"赤沙村铁匠铺，独立炉火将铁矿冶炼为粗铁。", "always":true},
	{"id":"forest_herb_house", "name":"青木草药屋", "atlas":"house", "region":Rect2(0,0,64,48), "at":Vector2(-1360,690), "body":Vector2(52,27), "door":Vector2(-1328,744), "description":"青木村的草药屋，在工作台调制大补汤与补气汤。", "always":true},
	{"id":"forest_chief_house", "name":"青木村长屋", "atlas":"house", "region":Rect2(464,64,48,64), "at":Vector2(-1100,680), "body":Vector2(36,24), "door":Vector2(-1076,750), "description":"木长居住的草顶木屋。", "always":true},
	{"id":"forest_wood_house", "name":"青木木梁屋", "atlas":"house", "region":Rect2(0,0,64,48), "at":Vector2(-1350,860), "body":Vector2(52,27), "door":Vector2(-1318,914), "description":"林禾的木梁屋，摆放着木家具和草席。", "always":true},
	{"id":"forest_stone_house", "name":"青木石拱屋", "atlas":"house", "region":Rect2(48,128,48,32), "at":Vector2(-1100,880), "body":Vector2(36,21), "door":Vector2(-1076,918), "description":"叶青的石拱小屋，木柜中可以储存物品。", "always":true},
	{"id": "herb_house", "name": "草药屋", "atlas": "house", "region": Rect2(0, 0, 64, 48), "at": Vector2(-260, 240), "body": Vector2(52, 27), "door": Vector2(-228, 294), "description": "林口的木屋，用采来的草药与满水木杯调制汤剂。"},
	{"id": "kitchen", "name": "灶房", "atlas": "desert", "region": Rect2(96, 0, 64, 48), "at": Vector2(345, 335), "body": Vector2(52, 27), "door": Vector2(377, 389), "description": "炊烟从泥砖灶房的烟囱升起，村民在这里煎肉。"},
	{"id": "house", "name": "旧泥屋", "atlas": "desert", "region": Rect2(96, 0, 64, 48), "at": Vector2(208, 112), "body": Vector2(52, 27), "door": Vector2(238, 166), "description": "村里最早搭起的泥屋，木梁和厚土墙能遮挡风沙。"},
	{"id": "round_house", "name": "圆顶屋", "atlas": "desert", "region": Rect2(0, 0, 48, 48), "at": Vector2(416, 96), "body": Vector2(36, 23), "door": Vector2(440, 150), "description": "圆顶覆着干草与叶片，屋里储存着编织用的藤条。"},
	{"id": "awning_house", "name": "棚檐土屋", "atlas": "desert", "region": Rect2(96, 48, 64, 64), "at": Vector2(690, 80), "body": Vector2(46, 27), "door": Vector2(714, 150), "description": "土屋门前留有遮棚，村民在这里晾晒陶碗。"},
	{"id": "chief_house", "name": "村长屋", "atlas": "desert", "region": Rect2(160, 0, 96, 64), "at": Vector2(630, 190), "body": Vector2(82, 32), "door": Vector2(654, 258), "description": "长屋兼作议事的地方，村长燧长也住在这里。"},
	{"id": "straw_house", "name": "草顶屋", "atlas": "house", "region": Rect2(464, 64, 48, 64), "at": Vector2(766, 300), "body": Vector2(36, 24), "door": Vector2(790, 370), "description": "厚厚的草顶压在木架上，屋旁放着狩猎与采集用具。"},
	{"id": "wood_house", "name": "木梁屋", "atlas": "house", "region": Rect2(0, 0, 64, 48), "at": Vector2(550, 412), "body": Vector2(52, 27), "door": Vector2(582, 466), "description": "木梁屋由村民一起搭建，门口常有人交换谷物和草绳。"},
	{"id": "stone_house", "name": "石拱屋", "atlas": "house", "region": Rect2(48, 128, 48, 32), "at": Vector2(198, 438), "body": Vector2(36, 21), "door": Vector2(222, 476), "description": "石块和泥土垒成的小屋，低矮的拱门朝向沙路。"}
]
const ROADS := [
	[Vector2(714,162),Vector2(824,180),Vector2(824,274),Vector2(790,386)],
	[Vector2(-1300,460),Vector2(-1200,620),Vector2(-1200,730),Vector2(-1328,770),Vector2(-1328,744)],
	[Vector2(-1200,730),Vector2(-1076,770),Vector2(-1076,750)],
	[Vector2(-1328,770),Vector2(-1328,822),Vector2(-1200,822),Vector2(-1076,822),Vector2(-1076,770)],
	[Vector2(-1328,822),Vector2(-1400,940),Vector2(-1318,940),Vector2(-1318,914)],
	[Vector2(-1076,822),Vector2(-1015,940),Vector2(-1076,940),Vector2(-1076,918)],
	[Vector2(-1400,940),Vector2(-1200,980),Vector2(-1015,940)],
	[Vector2(-1200,980),Vector2(-1000,1100)],
	[Vector2(12, 310), Vector2(-228, 310), Vector2(-228, 294)],
	[Vector2(-228, 310), Vector2(-800, 310), Vector2(-1600, 550), Vector2(-2200, 550)],
	[Vector2(12, 550), Vector2(-500, 550), Vector2(-800, 310)],
	[Vector2(12, 900), Vector2(-500, 900), Vector2(-1000, 1100), Vector2(-2000, 1300)],
	[Vector2(12, 1300), Vector2(-500, 1300), Vector2(-1000, 1100)],
	[Vector2(790, 386), Vector2(1200, 420), Vector2(1700, 480), Vector2(2070, 450)],
	[Vector2(222, 490), Vector2(108, 520), Vector2(36, 550)],
	[Vector2(582, 480), Vector2(800, 850), Vector2(1060, 1160), Vector2(1500, 1450)],
	[Vector2(800, 850), Vector2(100, 900)],
	[Vector2(360, 296), Vector2(408, 318), Vector2(412, 396), Vector2(377, 389)],
	[Vector2(188, 326), Vector2(174, 245), Vector2(157, 205)],
	[Vector2(110, 600), Vector2(188, 326), Vector2(320, 286), Vector2(326, 208), Vector2(246, 162)],
	[Vector2(254, 282), Vector2(326, 282), Vector2(360, 296), Vector2(430, 292), Vector2(430, 274)],
	[Vector2(326, 208), Vector2(378, 180), Vector2(440, 166), Vector2(550, 184), Vector2(714, 162), Vector2(714, 150)],
	[Vector2(360, 296), Vector2(500, 334), Vector2(548, 340), Vector2(654, 278), Vector2(654, 258)],
	[Vector2(654, 278), Vector2(790, 386), Vector2(790, 370)],
	[Vector2(548, 340), Vector2(582, 480), Vector2(582, 466)],
	[Vector2(188, 326), Vector2(222, 490), Vector2(222, 476)],
	[Vector2(222, 490), Vector2(400, 474), Vector2(582, 480)],
	[Vector2(790, 386), Vector2(846, 470), Vector2(940, 550)]
]
const PLAYERS := [
	{"id": "ali", "name": "阿砾", "role": "原始村民 · 男", "sprite": "Caveman", "at": Vector2(322, 224), "route": [Vector2(284, 205), Vector2(306, 238), Vector2(310, 282), Vector2(305, 218)], "dialogue": "先把井水和农田照顾好，村落才能慢慢长大。"},
	{"id": "heya", "name": "禾芽", "role": "原始村民 · 女", "sprite": "Cavegirl", "at": Vector2(284, 205), "route": [Vector2(284, 205), Vector2(306, 238), Vector2(310, 282), Vector2(305, 218)], "dialogue": "带上水桶打水，每片农田灌溉需要一满桶。"},
	{"id": "chief_priest", "name": "燧长", "role": "村长兼祭司", "sprite": "ShamanLion", "at": Vector2(548, 344), "route": [Vector2(548, 344), Vector2(610, 310), Vector2(646, 276), Vector2(530, 350)], "dialogue": "我既守护村里的约定，也在石台前为聚落祈愿。"}
]
const NPCS := [
	{"id": "shimu", "name": "石木", "role": "建屋村民", "sprite": "Caveman2", "at": Vector2(225, 484), "route": [Vector2(225, 484), Vector2(280, 474), Vector2(302, 418)], "dialogue": "新屋的木梁已经架好，下一步要补厚迎风的墙。"},
	{"id": "shahe", "name": "沙禾", "role": "田间村民", "sprite": "Cavegirl2", "at": Vector2(194, 286), "route": [Vector2(194, 286), Vector2(202, 314), Vector2(245, 307)], "dialogue": "这片小农田靠水井照料，别让土壤一直干着。"},
	{"id": "alie", "name": "阿猎", "role": "猎人", "sprite": "Hunter", "at": Vector2(804, 384), "route": [Vector2(804, 384), Vector2(856, 358), Vector2(842, 432)], "dialogue": "东边的沙地有兽足印，出村时留意石堆后的动静。"},
	{"id": "taoshu", "name": "陶叔", "role": "陶工", "sprite": "Villager", "at": Vector2(716, 160), "route": [Vector2(716, 160), Vector2(662, 170), Vector2(618, 218)], "dialogue": "门前的棚子能挡烈日，陶碗在下面慢慢晾干。"},
	{"id": "chitao", "name": "赤陶", "role": "搬运村民", "sprite": "Villager2", "at": Vector2(742, 266), "route": [Vector2(742, 266), Vector2(740, 310), Vector2(686, 304)], "dialogue": "土屋、木屋和草屋各有用处，材料得一点点搬来。"},
	{"id": "tuye", "name": "土叶", "role": "编织村民", "sprite": "Villager3", "at": Vector2(425, 157), "route": [Vector2(425, 157), Vector2(458, 174), Vector2(490, 155)], "dialogue": "晒好的草叶可以编成席子，也可以补在屋顶上。"},
	{"id": "tengqing", "name": "藤青", "role": "采集村民", "sprite": "Villager5", "at": Vector2(612, 484), "route": [Vector2(612, 484), Vector2(670, 478), Vector2(655, 420)], "dialogue": "南边还能找到干枝和草籽，我会带一些回来。"},
	{"id": "weiye", "name": "苇叶", "role": "牧养村民", "sprite": "Villager6", "at": Vector2(578, 363), "route": [Vector2(578, 363), Vector2(618, 350), Vector2(622, 306)], "dialogue": "猪圈门要记得关好，食槽在圈内靠右的地方。"},
	{"id": "yanbo", "name": "岩伯", "role": "年长村民", "sprite": "OldMan", "at": Vector2(297, 185), "route": [Vector2(297, 185), Vector2(310, 220), Vector2(270, 210)], "dialogue": "以前这里只有一间泥屋，现在沙路已经连起八间房了。"},
	{"id": "huaipo", "name": "槐婆", "role": "年长村民", "sprite": "OldWoman", "at": Vector2(493, 309), "route": [Vector2(493, 309), Vector2(527, 332), Vector2(497, 367)], "dialogue": "燧长是我们的村长，也是主持祭礼的人。"}
]

const FOREST_NPCS := [
	{"id":"forest_chief", "name":"木长", "role":"青木村村长", "sprite":"OldMan", "at":Vector2(-1180,835), "route":[Vector2(-1180,835),Vector2(-1076,822),Vector2(-1076,770)], "dialogue":"欢迎来到青木村。祭台可以存档和觉醒，西北边是草药屋。"},
	{"id":"forest_linhe", "name":"林禾", "role":"青木村村民", "sprite":"Villager5", "at":Vector2(-1328,790), "route":[Vector2(-1328,790),Vector2(-1328,822),Vector2(-1400,940)], "dialogue":"采来的草药可以带到村里的草药屋，别忘了准备一杯水。"},
	{"id":"forest_yeqing", "name":"叶青", "role":"青木村村民", "sprite":"Villager6", "at":Vector2(-1076,840), "route":[Vector2(-1076,840),Vector2(-1015,940),Vector2(-1076,940)], "dialogue":"桑叶采完后树还在，过两分钟就能再采。"}
]
