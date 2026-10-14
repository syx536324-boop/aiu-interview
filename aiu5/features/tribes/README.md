# 部落运行域

tribes.gd以start(session)、advance(delta)、interact、snapshot、perform、export_state/restore装配population、workers、war、relics、settlements及romance。UI仅读取Workshop快照并传递动作；规则见docs/TRIBES_ROMANCE_0.9.0.md。

population管理成员身份、职业成本、生命、年龄和有限等级增员。NPC库存id=npc:成员id，9格；魔法等级1且无元素，职业独立。workers用navigation缓存与失败重试控制行走，农务按环节等待，矿工共享mining有限矿脉。

war提供order/recall/advance；真实箭遵循射程、1秒间隔、遮挡、每箭1支。relics负责200生命、占领、300秒重建、可控同元素村长；主村失败只删除明确当前档文件，禁止续存/回退。settlements按每4人一住屋配设施，function标识供生产模块识别。

由Simulation在线时钟推进，暂停/离线不推进。Persistence在房间销毁前移出NPC，恢复成员及房间后post_restore续接红帘。
