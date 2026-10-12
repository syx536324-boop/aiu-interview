# 祭坛与献祭复活

`display.gd` 的 `start(world, inventory)` 在祭台北部建立祭坛台面、静态碰撞和北侧E交互点；原祭台正面E存档点保留。UI统一名为祭坛，库存容器稳定ID为 `altar:display`，容量21格，共享所有角色且兼容旧档。session打开既有储物界面，存取规则继续由inventory管理。

台面监听inventory.changed，仅在物品改变时刷新21个小图标；一个占用格显示一个图标，数量与整理在储物界面查看。库存序列化自动包含祭坛内容，无需独立存档文件；祭台回退同样恢复。世界碰撞交给navigation，附近运行/远区暂停交给streaming。

`offerings.gd` 的`start(session)`接入会话；`preview()`返回阵亡角色的稳定ID/名字与当前能否献祭；`sacrifice(target_id)`返回`{ok,message}`。UI发出`sacrifice_requested(target_id)`，session转交领域服务，UI不计算消耗或生命。只有存活操控者在北侧18单位内打开祭坛、选中右侧非空格、指定阵亡可控角色且存档服务可用时接受。任意物品消耗1单位，目标在广场安全位置复活，五项10并清除疾病/生存计时；保留当前操控者。空间不足或存档失败不消耗祭品，失败恢复目标原来房间、位置、计时及状态。成功后取消祭品选择，下一次需重新选中。全员阵亡继续独立祭台回退，不修改回退点。

验证：`tests/altar_revival_smoke.gd`覆盖真实C/E/鼠标输入、两名目标选择、单件/堆叠、室内复活、实际写入失败回滚、冻结与旧档迁移；`slot_quit_save_smoke.gd`两个进程验证正常关闭和重启后的魔力、复活结果及只扣一次的祭品。
