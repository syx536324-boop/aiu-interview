# 祭台摄像头赐予

`gifts.gd` 拥有祭台菜单、世界暂停、候选选择及原子赐予事务。`mapping.gd`固定首版18类映射；`provenance.gd`保留魔法来源；`camera_bridge.gd`启动独立本地推理进程并异步接收JSON与内存JPEG。界面位于`interface/gift_view.gd`，只展示快照、发送操作。

祭台正面 E → 赐予 → 稳定识别 → 定格选择 → 选择物品 → 确认赐予1件。每次仪式仅成功一次，30秒内确认，取消不生成。鸟、狗生成村庄动物；床进入背包并可在屋内部署；其他物品进入当前角色背包。剑映射木剑、斧映射石斧；杯子为空木杯、弓不自动赠箭。没有材质推断或额外数值加成。

仅赐予实例具有 `origin=player_gift/is_magical=true/magic_attribute=null/gift_event_id`。普通与魔法物品分开存放；装备、耐久、修复、柜箱和退出续玩保留来源。所有赐予均写入自动存档，失败回滚；不会自动更新祭台回退点。

接口：`start(session,camera)`、`open_menu()`、`begin_camera()`、`accept_snapshot(data)`、`freeze_frame()`、`select_candidate(id)`、`confirm()`、`close()`，`changed(snapshot)`供UI订阅。`inventory.gift_events`防止同一确认重复提交；跨仪式展示同一实物仍可再次赐予，未擅自增加实物去重玩法。

catalog.entries()为开始菜单提供18类识别名称、实际奖励、数量与去向，无需启动摄像头。具体使用方法见../../游戏玩法介绍.md。
