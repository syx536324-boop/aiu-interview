# 安卓 APK 构建

手机版本与Windows共享玩法源码，分别导出。当前安卓版本`0.10.8-android.3`，应用ID`com.aiu5.sandboxlife`，Android 8.0/API26及以上、OpenGL ES3.0，包含arm64-v8a、armeabi-v7a、x86_64。用户目标机V2307A为Android15；真机验收与模拟器验收应分别记录。

## 安装与操作

将`exports/android/沙盘上的生活-0.10.8-android.3.apk`发送到手机，使用文件管理器打开并按系统提示允许该来源安装。横屏游玩：左侧摇杆移动，按住奔跑，右侧交互／奔跑；点击场景瞄准攻击。底部进入背包、角色、全图、切换和更多；更多中包括耕地、种收、制作、布置、房屋升级、魔法与拆屋。装备锄头后点“耕地”开垦脚下，交互不触发开垦。手机系统返回键关闭当前面板或暂停。

进入后台会保存并暂停，回到游戏后点继续；离线不推进生产与生育。存档位于应用私有目录，电脑版存档不被迁移或改写。后续版本使用相同包名、签名覆盖安装，保留原Android存档。

祭台赐予使用手机后置相机，在首次打开时申请相机权限；18类模型在手机本地执行，不上传照片、不运行Windows Python服务。类别、45%阈值、连续3帧/0.6秒稳定条件及确认事务沿用电脑版。原型模型实物准确率仍取决于物体、光线与背景。

## 开发依赖

- Godot 4.7.2及完全相同版本的android_source.zip、Android导出模板。
- JDK17，Android SDK platform-tools、platforms;android-36、build-tools;36.1.0。
- 首次Gradle构建需要联网下载Gradle8.11.1、Android Gradle Plugin8.6.1与AndroidX，游戏运行和赐予不需要联网。
- 摄像头库ONNX Runtime Android1.23.2，源代码位于native/；`Prepare-Native.ps1`生成AAR，不将编译缓存、权重或签名密钥提交Git。
- 转换模型使用Python3.12、原18类`models/gifts18-prototype-v1.pt`和model-requirements.txt。已训练权重按models/README.md单独提供。

在Godot“编辑器设置→导出→Android”填写Java SDK与Android SDK路径，安装匹配的Android构建模板（项目→安装Android构建模板）。模板放到android/build，版本标记位于android/.build_version；不得将Windows模板替换为Android模板。

```powershell
python -m pip install -r packaging/android/model-requirements.txt
python packaging/android/export_model.py --weights models/gifts18-prototype-v1.pt --output .runtime/android/aiu_gifts18.onnx
pwsh -File packaging/android/Prepare-Native.ps1 -JavaHome 'C:\tools\jdk17' -AndroidSdk 'C:\tools\android-sdk' -Model '.runtime\android\aiu_gifts18.onnx'
# 使用自己的长期签名密钥；密码通过环境变量提供，不能写入版本库。
$env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD='在本机安全提供的密码'
pwsh -File packaging/android/Build.ps1 -Godot 'C:\tools\Godot.exe' -JavaHome 'C:\tools\jdk17' -AndroidSdk 'C:\tools\android-sdk' -KeyStore 'C:\private\aiu5-android-release.jks' -KeyAlias aiu5
```

密钥和密码应独立安全备份；丢失后无法用原签名升级。不要用Android QA预设代替正式签名版，QA包名不同且含隔离测试入口。

模型转换验证要求输出1×22×5376，使用相同随机输入比较Torch/ONNX结果；触屏与生命周期验证见tests/mobile_probe.gd。最终APK需验证签名、Manifest、三种ABI、模型资源、安卓15启动/保存/相机，以及原Windows exe/pck/安装包SHA256未变。最终记录见docs/VERIFICATION_ANDROID_0.10.8.json。

android.3新增工作台1/2/3级并行生产、左右双栏直接触屏滑动，及魔法选择／赐予／NPC升级教程；可在“更多→教程”重看。专项验证入口：`res://tests/workbench_update_probe.tscn`，使用AIU5_BENCH_DIR隔离存档。
