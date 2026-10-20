# 安卓表现层与手机摄像头

`bootstrap.gd`是Android启动入口，装配原开始菜单、中文字体、横屏缩放及后台保存/暂停；Windows继续使用原入口。`controls.gd`只展示按钮并转发会话动作，农业、伤害、魔法、材料和保存规则仍由现有领域模块负责。

`joystick.gd`把方向强度转成原有Input动作，`touch_button.gd`独立追踪手指，允许移动、奔跑与触屏攻击同时操作。手机版右侧按钮为「交互」，其正下方是「奔跑」；不再提供独立攻击键，点击世界（敌人或地面）即触发原有战斗动作。触屏入口仅在Android或开发预览`AIU5_MOBILE_PREVIEW=1`时装配；菜单开启、后台、换场景时释放虚拟按键。返回按钮与系统返回键依次关闭面板或打开暂停菜单。

`camera.gd`把AiuGiftCamera原生插件的JSON信号转为原祭台的updated快照。Camera2和ONNX仅在打开赐予时运行，关面板/后台释放相机。权限拒绝显示错误，不生成假候选或奖励。Windows仍使用原Python桥接。

开发验证入口`res://tests/mobile_probe.tscn`，必须使用独立AIU5_BENCH_DIR和存档路径。Android QA预设使用独立包名，仅用于模拟器验收，不作为用户安装包。构建与签名见`packaging/android/README.md`。

更多菜单中的“教程”转交onboarding.review_features，不伪造拾取或制作成果。安卓QA先检查原操控、相机和生命周期，再启动workbench_update_probe专项验证。
