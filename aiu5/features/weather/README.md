# 高地雾霾

`haze.gd.start(world)`将雾霾绘制连接到地貌模块。高原和山地使用相同规则：登山前整区绘制90%浓度遮罩；登山后视口外圈30%的三层雾霾，从外向内为90%、70%、40%。最外层最浓，中央视野保持清晰。三层由互不重叠的矩形条绘制，四个角不会重复混合浓度。视口范围按相机zoom换算为世界像素。

`on_highland()`检查当前操控角色所在地；`range_scale()`在高地返回0.7，平地返回1。Combat只在远程路径使用缩放，近战沿用武器自身距离。`visited`为本次运行内的登山状态。

规则常量为PRE_VISIT_ALPHA、RING_ALPHAS、BAND、RANGE_SCALE；`tests/haze_probe.gd`验证确认的浓度、高原及山地射程和云野敌对态度。视觉检查见`tests/maintenance_visual.gd`，硬件采样见`tests/performance_probe.gd`。

`tests/haze_pixels_probe.gd`在实际GPU上测量四侧和角落的像素，验证90%／70%／40%真实浓度、由外向内递减以及中央透明，防止方向错误和重复叠加。
