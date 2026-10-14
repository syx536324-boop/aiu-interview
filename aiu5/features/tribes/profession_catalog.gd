# Defines civilian, combat and worker career costs independently of magic progression.
extends RefCounted
const LABELS := {"civilian":"平民","archer":"弓箭手","charger":"战士","farmer":"农民","miner":"矿工","chief":"村长"}
const COSTS := {
 "civilian:2":{"bread":3},"civilian:3":{"bread":5,"wood":5},
 "farmer:4":{"hoe":1,"bread":10,"stone":3,"wood":1,"crude_iron":1},"farmer:5":{"hoe":1,"bread":15,"crude_iron":3},
 "miner:4":{"pickaxe":1,"stone":15,"crude_iron":1},"miner:5":{"iron_pickaxe":1,"crude_iron":10},
 "archer:4":{"bow":1,"crude_iron":2,"wood":15},"archer:5":{"bow":2,"crude_iron":10,"wood":50},
 "charger:4":{"bread":10,"stone_sword":1,"crude_iron":5},"charger:5":{"bread":15,"iron_sword":1,"crude_iron":10}}
static func life(career: String, rank: int) -> float:
 var value := 10.0+7.0*(mini(3,rank)-1)
 if rank>=4: value+=float({"farmer":5,"miner":5,"archer":3,"charger":10}.get(career,0))*(rank-3)
 return value
static func weapon(career: String, rank: int) -> String:
 if career=="archer" and rank>=3: return "bow"
 if career=="charger" and rank>=3: return "wood_sword" if rank==3 else ("stone_sword" if rank==4 else "iron_sword")
 return ""
static func damage(career: String, rank: int) -> float:
 if career=="archer": return float({3:1,4:3,5:5}.get(rank,0))
 if career=="charger": return float({3:1,4:3,5:5}.get(rank,0))
 return 0.0
static func work_interval(career: String, rank: int, ore := "") -> float:
 if career=="farmer": return 10.0 if rank==5 else 15.0
 if career=="miner": return float(({"stone":6,"coal":12,"iron_ore":30} if rank==5 else {"stone":10,"coal":20,"iron_ore":60}).get(ore,0))
 return 0.0
static func upgrades(record: Dictionary) -> Array[Dictionary]:
 var result: Array[Dictionary]=[]
 var rank := int(record.level); var career := str(record.career)
 if rank>=5 or career=="chief" or float(record.get("child_left",0))>0: return result
 var targets: Array=[career]
 if rank==3 and career=="civilian": targets=["farmer","miner"]
 for next: String in targets:
  var cost: Dictionary=COSTS.get(next+":"+str(rank+1),{})
  if not cost.is_empty(): result.append({"career":next,"level":rank+1,"cost":cost})
 return result
