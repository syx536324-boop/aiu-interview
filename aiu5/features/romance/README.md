# 婚恋生育

romance.gd管理每对共享好感、每对婚房/多名配偶、同行、600秒孕期、120秒接生窗口及随机子女性别。通过tribes的snapshot/perform请求访问，材料与人口判断在后端。送面包、结婚、接生复用production.commit的完整保存回滚。

advance由Simulation在线时钟推进。NPC孕妇提前走向最近本方草药屋并自动接生；新生儿在草药屋内，population管理300秒成长。主村出生无30上限，外村含胎儿预留最多30。export_state/restore保存关系和所有阶段，离线不计时。

curtain.gd仅绘制0.65秒合拢、1秒闭合、0.65秒打开的喜庆褶皱红帘。elapsed归后端ceremony保存；动画暂停世界、阻挡其他菜单，post_restore恢复尚未完成动画。像素双喜由笔画绘制，避免缺少字体时出现方块。

weddings.gd管理玩家主持NPC婚礼：选对象/婚房，面包16平分各8，免NPC好感门槛。保存一次自动进屋/婚床/怀孕流程，接生后结束；again由玩家发起下一次。对romance用WeakRef避免引用循环，busy暂时让职业/战斗行动让路。旧一夫一妻字典迁为每对a/b/house记录。
