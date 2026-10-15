# 魔法、装备与技能

catalog管理四系独占觉醒、1–100级经验、主干／分支点数预算与晶石里程碑。progression以角色ID持有状态；UI通过快照展示，发出请求，由session转交本模块，main只装配。

角色只有一个觉醒属性；魔力上限10＋（等级－1）×5，每级＋5技能点，主干5项各10点。击杀／首次物品成就各25魔法点，未觉醒先累计。每到5的倍数等级保留一颗对应晶石奖励，支持跨多级；旧档补发，以crystal_milestone避免重复，crystal_pending保存满包奖励。achievements.save_to在同次保存事务中投递可容纳奖励，失败恢复背包／经验／里程碑；claim_crystals可手动领取。

skill_catalog／skills执行五个主干，被动与Z／H／K／L保留。branch_catalog定义36项，branches负责分支施放、目标／代价／冷却、范围设施、草丛、控制／护盾／减伤／反伤／余烬及在线时钟；branch_visual使用原生像素绘制。房屋操作调用construction契约，不能免除材料。真实规则见../../docs/ELEMENTAL_BRANCHES.md。

公共接口：start(session)、awaken(id,element)、credit_points／award_points、unlock(id,skill)、select_branch(id,skill)、claim_crystals(id)、equip／equip_weapon；snapshot／branch_hud为显示契约。skills.cast(rank,at)与branches.cast(skill_id,at)分别执行主干和分支。失败提交回退完整快照，不扣材料、魔力和点数。

damage_rate(id,context)由穿戴装备、主干水盾、不同技能来源防护相乘，普通封顶50%；石阵再乘0.9。branches.speed_rate同来源取最强、不同来源相乘，最低保留40%速度。护盾只取最强，absorb在减伤之后执行；reflect不会递归，prevent_death执行一次余烬保护。control_locks让主干与分支共享同目标10秒禁锢间隔。

皮装备每件1防御／5%免伤，四件20%，普通和赐予一致；水盾组合44%。铁装备防御3／2／2／1，满套40%。背包装备交换保持原实例来源与武器耐久，火把独立槽保留旧规则。

export_state／restore包含角色、主干effects和分支branches。恢复仅接受等级／前置／总技能点预算内的学习记录；旧六节点只保留前五并一次退款。分支设施、草丛、技能冷却和效果不离线推进。

验证：tests/branches_smoke.tscn（36项效果、叠加、施工、晶石、失败保存、真实重启）；armor_probe.tscn、elemental_smoke.gd、item_update_probe.tscn回归原有规则。

## 0.8.1接口与规则

铁装备防御3／2／2／1、满套40%。progression.attack_damage(id)组合基础攻击、固定赐予等级加成和主干赋能；weapon_enchants拥有四系命中、角色共享冷却及持久化。rune_art统一四属性颜色和符号；branches管理施法、持续与被动视觉并随室内外场景挂接。export_state／restore新增enchants；减速由branches.speed_rate合并附魔与技能来源。


## 0.10.3计划复核

speed_rate同时合并状态与玩家增减益中的减速，不同来源相乘、同来源取强，速度最低40%。resident正常走路和跑步、工作人员及日常移动均读取此倍率，已计算倍率的守卫／出征不重复相乘。NPC施法复用cast_for，锁定实际目标、自己的魔力和真实生命池；移除近24像素的穿墙豁免，土系紧急瞬移朝安全方向。
