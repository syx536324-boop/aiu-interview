# Windows 安装与打包

Windows 10/11 x64，安装包 `AIU5-Setup-0.10.8-win64.exe`。双击安装，默认安装到当前用户 `%LOCALAPPDATA%\Programs\AIU5`，从开始菜单“沙盘上的生活”运行。首版模型、Python 3.12、CPU Torch、OpenCV、Ultralytics和运行所需VC DLL均随包附带；不需要Godot编辑器、D盘训练环境、网络或另装Python。源码同步到 https://github.com/syx536324-boop/aiu-interview 。0.9.1修复制作、冶炼和散落材料补充的在线计时。正式发布版本见：https://github.com/syx536324-boop/aiu-interview/releases 。

祭台正面E → 赐予 → 定格 → 选择 → 确认。首次加载模型需数秒；稳定目标阈值0.45、3帧/0.6秒。摄像头仅在该面板开启，不录制或上传图像。Windows需允许桌面应用访问摄像头；设备被占用时先关闭相关应用。该安装包使用CPU推理，源码可通过AIU5_CAMERA_PYTHON使用GPU环境。18类首版模型仍须按实物、背景和光照逐类验收。

24真实分钟为一天，1真实分钟为游戏一小时，暂停/菜单/离线不走时。安装/卸载不删除 `%APPDATA%\Godot\app_userdata\AIU5 · 赤沙村` 玩家存档。重装前可自行备份该目录。

## 从源码构建

准备Godot 4.7.2 Windows x64编辑器和官方同版本导出模板、Python 3.12 x64嵌入式发行包及Inno Setup 7。将训练模型放到`models/gifts18-prototype-v1.pt`，SHA256见models/README.md；将包含依赖的嵌入式环境放到`runtime/`（python312._pth含site-packages、../services/gift_camera和import site），VC运行DLL放在runtime根目录。依赖版本见runtime-requirements.txt，runtime目录不提交Git。

将官方windows_release_x86_64.exe和windows_debug_x86_64.exe模板放到export_templates目录，然后运行：

```powershell
pwsh -File packaging/windows/build.ps1 -Godot 'C:\tools\Godot.exe' -ISCC 'C:\tools\Inno Setup\ISCC.exe'
```

输出exports/windows，安装包exports/AIU5-Setup-0.10.8-win64.exe。脚本核对模型哈希、runtime和原生库存在，导出游戏，复制物理服务与模型，再生成安装器。应用通过本地HTTP随机会话令牌与Python服务通信，运行时路径均相对安装目录。

0.7.2采用已确认的透明像素沙盘图标，统一游戏窗口、Windows程序文件、安装器和开始菜单；图标原图及七尺寸ICO见assets/branding。


0.10.0合并NPC态度与技能、地形河桥、新手指引、动物与资源密度改动。安装包需先安装至隔离目录，运行npc_attitude_probe与npc_completion_probe；正式安装前备份并核对玩家存档SHA256。交付证据位于docs/VERIFICATION_0.10.0.json。


0.10.1本地修复：开局阿林与小满等友方成年NPC在无任务时会在村内走动并停留；对话、工作、婚恋和战斗优先。旧档兼容，不补人、回血或复活。修复及验证详见docs/FRIENDLY_NPC_FIX_0.10.1.md。本次尚未上传或发布。


0.10.2本地修复：NPC逐物理帧连续移动，起步与停步平滑过渡，按实际步行距离切换四向行走姿势；日常、工作、婚恋及出征共用物理移动。保持在线经营计时、速度、碰撞及暂停规则。详见docs/NPC_MOTION_0.10.2.md。本次未上传或发布。


0.10.3本地复核：保留森林初始中立；修复祭坛禁区超过5秒后近战准备反复重置而没有伤害。补齐受击逃跑／被堵反击、搜索返回、实际目击与亲属记忆、玩家指挥归属、援助、偷窃通知、正常走路减速、压制箭命中及土系安全撤离。NPC标记按真实态度区分。逐项证据见docs/NPC_PLAN_AUDIT_0.10.3.md。本次未上传或发布GitHub。

## 开源代码

本项目原创代码采用AGPL-3.0-only，完整许可与运行依赖说明见[LICENSE](../../LICENSE)和[OPEN_SOURCE.md](../../OPEN_SOURCE.md)。打包脚本会把LICENSE、开源说明及第三方声明一同复制到后续安装包。上文0.10.1至0.10.3“本地修复”是先前交付阶段记录；这些改动现已随[0.10.3 Release](https://github.com/syx536324-boop/aiu-interview/releases/tag/v0.10.3)发布。


0.10.4本地修复包：修复角色被动／增益特效在场景卸载后失效导致的闪退，保留AGPL许可证及第三方声明。回归入口为tests/scene_transition_probe.tscn；需设置独立的AIU5_TRANSITION_DIR，防止测试使用玩家数据。


0.10.5本地包修复户外部署预览反复全图寻路导致的卡死。回归入口tests/building_deployment_probe.tscn，必须设置AIU5_BENCH_DIR为独立空目录或玩家数据的私有副本目录。保留0.10.4场景切换修复与AGPL及第三方声明。本次不上传GitHub。


0.10.6本地更新：工作台及未转为建筑的建筑台增加移动／回收入口，开局工作台可回收且不会读档重刷。回归入口tests/bench_management_probe.tscn，必须设置AIU5_BENCH_DIR为隔离目录。保留0.10.4场景切换与0.10.5部署性能修复，本次不上传GitHub。


0.10.7本地更新包含哥布林与矿洞护卫、矿洞调暗。回归入口tests/goblins_probe.tscn使用隔离AIU5_BENCH_DIR；另复核工作台回收、部署性能和场景切换。保留AGPL与第三方声明，本次不上传GitHub。

0.10.8本地更新：锄头可装备为武器，装备后Q开垦脚下田格，E不触发开垦。回归场景tests/hoe_probe.tscn，必须设置AIU5_BENCH_DIR为独立空目录或私有旧档副本；验证实际背包操作、Q输入、耐久、保存重载和E原有交互。本次不上传GitHub。
