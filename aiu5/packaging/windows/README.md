# Windows 安装与打包

Windows 10/11 x64，安装包 `AIU5-Setup-0.7.2-win64.exe`。双击安装，默认安装到当前用户 `%LOCALAPPDATA%\Programs\AIU5`，从开始菜单“沙盘上的生活”运行。首版模型、Python 3.12、CPU Torch、OpenCV、Ultralytics和运行所需VC DLL均随包附带；不需要Godot编辑器、D盘训练环境、网络或另装Python。源码和发布包见 https://github.com/syx536324-boop/aiu5 。

祭台正面E → 赐予 → 定格 → 选择 → 确认。首次加载模型需数秒；稳定目标阈值0.45、3帧/0.6秒。摄像头仅在该面板开启，不录制或上传图像。Windows需允许桌面应用访问摄像头；设备被占用时先关闭相关应用。该安装包使用CPU推理，源码可通过AIU5_CAMERA_PYTHON使用GPU环境。18类首版模型仍须按实物、背景和光照逐类验收。

24真实分钟为一天，1真实分钟为游戏一小时，暂停/菜单/离线不走时。安装/卸载不删除 `%APPDATA%\Godot\app_userdata\AIU5 · 赤沙村` 玩家存档。重装前可自行备份该目录。

## 从源码构建

准备Godot 4.7.2 Windows x64编辑器和官方同版本导出模板、Python 3.12 x64嵌入式发行包及Inno Setup 7。将训练模型放到`models/gifts18-prototype-v1.pt`，SHA256见models/README.md；将包含依赖的嵌入式环境放到`runtime/`（python312._pth含site-packages、../services/gift_camera和import site），VC运行DLL放在runtime根目录。依赖版本见runtime-requirements.txt，runtime目录不提交Git。

将官方windows_release_x86_64.exe和windows_debug_x86_64.exe模板放到export_templates目录，然后运行：

```powershell
pwsh -File packaging/windows/build.ps1 -Godot 'C:\tools\Godot.exe' -ISCC 'C:\tools\Inno Setup\ISCC.exe'
```

输出exports/windows，安装包exports/AIU5-Setup-0.7.2-win64.exe。脚本核对模型哈希、runtime和原生库存在，导出游戏，复制物理服务与模型，再生成安装器。应用通过本地HTTP随机会话令牌与Python服务通信，运行时路径均相对安装目录。

0.7.2采用已确认的透明像素沙盘图标，统一游戏窗口、Windows程序文件、安装器和开始菜单；图标原图及七尺寸ICO见assets/branding。
