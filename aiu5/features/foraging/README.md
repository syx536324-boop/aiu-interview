# 起步材料与公共工作台

取消开局工具后，`foraging.gd` 在赤沙村、青木村各提供固定公共工作台与散落木头/石头。靠近材料E空手拾取，120在线秒后补充。公共工作台不能搬动或回收，可制作自己的工具和工作台。

`start(session)` 注册场景和交互点，`gather(id)` 原子保存拾取，满包或存档失败保留材料；`elapse(delta)` 由simulation时钟推进，`export_state/restore` 接入完整存档。只读重启不会重置资源倒计时，暂停和离线不推进。组合入口不承载经营规则。

## 0.9.1在线计时修复

Production及Foraging由统一Simulation时钟驱动；start显式启用领域的process标志。这两个节点无需自己的_process回调，避免重复计算时间。tests/crafting_clock_probe.tscn以真实帧检查菜单中的进度、冶炼、资源补充、暂停及读档，不直接调用elapse。
