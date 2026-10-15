# 保存NPC对玩家行为的记忆，结算个人好感事件并按在线时钟节流提示。
extends RefCounted

const KIN_RELATIVE := -40
const WITNESS := -10
const VICTIM := -30
const AIDED := 10
const NORMAL_LIMIT := 10
const PROMPT_INTERVAL := 10.0

# 事件类型 -> 对应的中文短句；severity>=2 的事件进入严重记忆。
const LINES := {
	"gift_bread": "谢谢你送的面包。",
	"attacked": "你上次动手打了我，我记得。",
	"attacked_kin": "你伤害了我的家人，这笔账我记着。",
	"killed_kin": "你害死了我的家人，我不会忘记。",
	"killed_villager": "你杀了我们村的人，别靠近我。",
	"witness_attack": "有人攻击村民！",
	"saw_theft": "我亲眼看见你偷东西。",
	"relic_attacked": "离祭坛远一点。",
	"aided": "你上次帮我们守住了村子。",
	"trespass": "这里不是你能进来的地方。"
}

var runtime: Node
var records: Dictionary = {}
var overrides: Dictionary = {}
var clock := 0.0
var day := 0

func start(owner: Node) -> void:
	runtime = owner

func now() -> float:
	if is_instance_valid(runtime) and runtime.has_method("now"):
		return float(runtime.now())
	return clock

func advance(delta: float) -> void:
	clock += maxf(0.0, delta)

func record(npc_id: String) -> Dictionary:
	var npc := _key(npc_id)
	if not records.has(npc):
		records[npc] = {"events": [], "severe": {}, "prompted": {}}
	return records[npc]

func _key(npc_id: String) -> String:
	return npc_id.trim_prefix("npc:")

# 记录一个事件并按规则结算受影响角色的好感；同一事件只扣一次。
func remember(npc_id: String, event: String, actor_id: String, severity := 1, detail := "") -> void:
	if npc_id == "" or actor_id == "": return
	var entry: Dictionary = record(npc_id)
	var at := now()
	entry.severe = _prune_severe(entry, at)
	entry.events.push_front({"event": event, "actor": actor_id, "at": at, "severity": severity, "detail": detail})
	if entry.events.size() > NORMAL_LIMIT:
		entry.events.resize(NORMAL_LIMIT)
	var affected: Array = []
	var _silent := false
	match event:
		"gift_bread":
			# 赠礼的个人好感由 romance 的＋5统一结算，这里只留记忆，不重复加好感。
			_silent = true
		"aided":
			affected.append([npc_id, AIDED])
		"attacked":
			affected.append([npc_id, VICTIM if severity >= 2 else WITNESS])
		"attacked_kin", "killed_kin":
			# 受害者亲友：对行为者 －40。
			affected.append([npc_id, KIN_RELATIVE])
		"killed_villager":
			affected.append([npc_id, VICTIM if severity >= 2 else WITNESS])
		"witness_attack", "saw_theft", "trespass":
			affected.append([npc_id, WITNESS])
	for entry_pair: Array in affected:
		_liking(actor_id, str(entry_pair[0]), int(entry_pair[1]))
	if severity >= 2:
		if entry.severe.is_empty() or float(entry.severe.get("severity", 0)) <= float(severity):
			entry.severe = {"event": event, "actor": actor_id, "at": at, "severity": severity, "detail": detail}
	if not _silent:
		_feedback(npc_id, event)

func mark_severe(npc_id: String, event: String, actor_id: String, detail := "") -> void:
	var entry: Dictionary = record(npc_id)
	if entry.severe.is_empty() or float(entry.severe.get("severity", 0)) <= 2.0:
		entry.severe = {"event": event, "actor": actor_id, "at": now(), "severity": 2, "detail": detail}

func memory_of(npc_id: String) -> Array:
	return record(npc_id).events.duplicate(true)

func last_severe(npc_id: String) -> Dictionary:
	return record(npc_id).severe.duplicate(true)

# 关系线索用于对话与提示；同一NPC与同类事件至少间隔10在线秒。
func can_prompt(npc_id: String, event: String) -> bool:
	var entry: Dictionary = record(npc_id)
	return now() - float(entry.prompted.get(event, -1000.0)) >= PROMPT_INTERVAL

func _feedback(npc_id: String, event: String) -> void:
	if not LINES.has(event): return
	if runtime.session.world.active_resident.resident_id.begins_with("npc:"): return
	if not can_prompt(npc_id, event): return
	record(npc_id).prompted[event] = now()
	runtime.session._set_notice(_speaker(npc_id) + "：" + str(LINES[event]))

func _speaker(npc_id: String) -> String:
	var id := _key(npc_id)
	var member: Dictionary = runtime.population.members.get(id, {})
	return str(member.get("name", "村民"))

func line_for(npc_id: String) -> String:
	var severe: Dictionary = last_severe(npc_id)
	if not severe.is_empty(): return str(LINES.get(str(severe.event), "我记得你做过的事。"))
	var events: Array = memory_of(npc_id)
	for entry: Dictionary in events:
		if LINES.has(str(entry.event)): return str(LINES[entry.event])
	return ""

func _prune_severe(entry: Dictionary, at: float) -> Dictionary:
	if entry.severe.is_empty(): return entry.severe
	# 严重记忆长期保留，只在同一事件已过1000在线秒且没有新事件时淡化为普通记忆。
	if at - float(entry.severe.get("at", at)) > 1000.0:
		return {}
	return entry.severe

func _liking(actor_id: String, npc_id: String, delta: int) -> void:
	if runtime == null: return
	var target := team_id(npc_id)
	# 个人好感按事件独立结算并夹在0～100；romance.liking 原本只在下限50使用，
	# 因此这里保存覆盖值，由 memory.liking() 统一对外提供，避免负向事件被吞掉。
	var current := liking(actor_id, target)
	overrides[runtime.romance.pair(actor_id, target)] = clampi(current + delta, 0, 100)

# 个人好感统一入口：有事件覆盖值时用覆盖值，否则沿用既有婚恋数据。
func liking(actor_id: String, npc_id: String) -> int:
	if runtime == null: return 50
	var target := team_id(npc_id)
	var key: String = runtime.romance.pair(actor_id, target)
	if overrides.has(key): return clampi(int(overrides[key]), 0, 100)
	return runtime.romance.liking(actor_id, target)

func set_liking(actor_id: String, npc_id: String, value: int) -> void:
	if runtime == null: return
	overrides[runtime.romance.pair(actor_id, team_id(npc_id))] = clampi(value, 0, 100)

# 统一成 "npc:<成员id>" 形式，供 romance 的成对好感使用。
func team_id(npc_id: String) -> String:
	var id := _key(npc_id)
	return id if id.begins_with("npc:") else "npc:" + id

func export_state() -> Dictionary:
	return {"records": records.duplicate(true), "overrides": overrides.duplicate(true), "clock": clock, "day": day}

func restore(data: Dictionary) -> void:
	records = data.get("records", {}).duplicate(true) if data.get("records", {}) is Dictionary else {}
	overrides = data.get("overrides", {}).duplicate(true) if data.get("overrides", {}) is Dictionary else {}
	clock = maxf(0.0, float(data.get("clock", 0.0)))
	day = maxi(0, int(data.get("day", 0)))
