# 成就

`achievements.gd.start(session)` 接入角色进度与完整存档，并把 `save_to` 挂到库存保存钩子上。成就按“每名角色首次获得一种物品”自动判定：`catalog.gd.entries()` 由物品目录生成全部条目（含赐予所得的鸟、狗），`item_key` 把三档水桶归一为同一种，`REWARD=25`。

`discover(actor_id, item, held)` 只对未完成条目调用一次 `magic.credit_points` 并记录完成，重复获得同种物品不再奖励。开局补给不是“获得”：`inventory/catalog.gd` 的 `STARTING`（小麦、水稻种子各3）与 `catalog.gd.starting_count` 一起定义每件物品的开局持有量，`held <= starting_count` 时不判定成就，因此开局不会白送魔法点；之后真正持有超过开局数量（例如收获得到第4个种子）才计入。`collect_discoveries()` 在每次保存前按物品统计可控角色的背包持有量，并连同装备、火把格和赐予事件把新发现一次性计入同一次保存。`save_to` 失败时回滚完成记录和魔法点，保证“物品与成就同事务”。

`snapshot(actor_id)` 返回只读的成就栏数据；`complete(actor_id, achievement_id)` 保留给显式成就，同样每角色只奖励一次 25 魔法点。

入口：C→角色属性→成就。UI只展示后端快照并显示实际 25 魔法点。验证：`tests/item_update_probe.gd`（开局不计入、真实获得计入、重复物品、失败回滚、重载不重复）与 `tests/rules_update_smoke.gd`。

## 魔法分支接入（0.8.0）

save_to先结算首次物品成就，再在背包容量许可时投递magic保留的晶石奖励，并结算晶石首次获得。写入失败同时恢复成就、魔法状态与背包，晶石不能因失败丢失或重复。
