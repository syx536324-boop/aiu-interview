# 独立村落存档

`library.gd` 提供 `slots()`、`resolve(id)`、`create_slot(title)` 和 `import_legacy()`，管理稳定ID目录、名称、完整快照有效性及旧存档只复制导入。默认根目录为 `user://save_slots`，测试通过 `AIU5_SAVES_DIR` / `AIU5_LEGACY_PATH` 隔离。每份目录独立持有自动、祭台和姓名文件。列表只允许加载有效快照，新建从不覆盖其他村落。

`profile.gd` 的 `configure(world)` 在main的_enter_tree读取选中快照的settlement；starter只建灶房、旧泥屋、圆顶屋及三名可控居民，expanded保留八屋十三人。旧快照未声明类型时默认expanded。菜单选择路径后，原persistence/inventory模块继续负责实际状态读写与事务。


新建slot.json同时保存随机seed；已有无种子槽位在resolve选择进入时生成并写入一个种子，避免每次启动不同。完整快照resource_world.seed优先于元数据，恢复后仍保持原世界。controller只将选定seed传给Profile；Profile在World构建前设定world.resource_seed。生成版本不支持或种子非法的快照不可进入。
