# 本地摄像头服务

只绑定127.0.0.1；每会话随机请求令牌。首版18类模型加载时校验名单。选择赐予才开启摄像头，640×480预览、512推理、最多4次/秒；GPU优先，失败回退CPU。连续框匹配至少3帧且0.6秒才可选。图像仅在内存，不上传、不录制。

`config.json`默认使用项目或安装目录内的`runtime/pythonw.exe`，模型与server.py均取物理文件。导出后从AIU5.exe旁查找，避免PCK内部路径和开发机路径。Windows安装包附完整CPU环境，无需另装Python。源码可用`AIU5_CAMERA_PYTHON`指定GPU兼容环境；需要Torch、OpenCV、Ultralytics，版本见packaging/windows/runtime-requirements.txt。

GET `/snapshot`返回`{session_id,status,sequence,frame_jpeg,candidates,device,message}`；POST `/stop`结束，均需`X-AIU5-Token`。服务不修改存档。关闭界面、退出游戏、父进程退出或请求断开20秒后释放摄像头。Godot异步轮询。

日志：`%APPDATA%/Godot/app_userdata/AIU5 · 赤沙村/camera-gifts.log`。摄像头异常时检查Windows摄像头权限、设备编号或设备占用，再关闭面板重试。
