# 部落运行域

tribes.gd以start(session)、advance(delta)、interact、snapshot、perform、export_state/restore装配population、workers、war、relics、settlements、romance及0.10.0新增的relation(记忆)、guards(日常行为)、npc_skills(招式)运行域。UI仅读取Workshop快照并传递动作；规则见docs/TRIBES_ROMANCE_0.9.0.md与docs/NPC_ATTITUDE_SKILLS_0.10.0.md。

population管理成员身份、职业成本、生命、年龄和有限等级增员。NPC库存id=npc:成员id，9格；魔法等级1且无元素，职业独立。workers用navigation缓存与失败重试控制行走，农务按环节等待，矿工共享mining有限矿脉。

war提供order/recall/advance；真实箭遵循射程、1秒间隔、遮挡、每箭1支。relics负责200生命、占领、300秒重建、可控同元素村长；主村失败只删除明确当前档文件，禁止续存/回退。settlements按每4人一住铺配设施，function标识供生产模块识别。

## 声誉与记忆（0.10.0）

tribes.gd保存每个部落对玩家村落的声望(-100～100)：森林部落初始0（中立）、野蛮与云野初始-50（敌对）。standing/attitude/display_attitude/hostile/alert/trusted是行为裁决入口，zone与relic_zone给出行走与禁区边界。事件结算：正常赠面包＋1（每游戏日每部落上限5）、帮助抵御＋10（同部落间隔5在线分钟）、偷窃－10、攻击村民－20（同一受害者60在线秒去重）、杀死村民－35（按死亡事件一次）、攻击圣品直接－100。归附流程优先于外部声望：relics.owner==player时一律按本方规则。

relation_memory.gd记录每名NPC的事件与个人好感变化：受害者－30、目击者－10、被帮助者＋10、受害者的配偶/亲属－40。每名NPC保留最近10条普通事件与一次严重记忆，同一NPC同类提示至少间隔10在线秒；严重记忆不能靠一次送礼消除。

## 行为与招式（0.10.0）

guards.gd接管未归附部落成员的日常状态（生活/巡逻/观察/警告/接敌/准备/攻击/搜索/撤退/返回），追击不超领地外240世界像素且最长20在线秒，失去目标只搜索最后看见的位置5在线秒，同场最多3名近战贴身。war.gd仍只负责本方出征与护卫，两者不会同时驱动同一单位。

npc_skills.gd提供3级及以上战士的冲刺斩/招架、3级及以上弓箭手的压制箭，以及四系村长各两招元素技能；村长只消耗自己的魔力，冷却统一由在线时钟推进。

由Simulation在线时钟推进，暂停/离线不推进。Persistence在房间销毁前移出NPC，恢复成员及房间后post_restore续接红帘；声望、记忆、每日赠礼额度、援助冷却与剩余招式冷却都进入同一存档字典，旧档缺字段时补默认值且不重播扣分或奖励。


0.10.0：箱柜取物由inventory.transfer_commit进入complete_storage_transfer，将物品变化和每操作−10声誉放在同一保存事务；自有与归附财物豁免。war只处理出征及友方，guards单独管理当地未归附成员，避免重复推进与重复攻击。
