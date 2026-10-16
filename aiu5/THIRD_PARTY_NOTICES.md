# 第三方素材与依赖

本项目原创代码的AGPL-3.0-only授权见[LICENSE](LICENSE)与[开源说明](OPEN_SOURCE.md)。下列第三方内容继续使用其原有许可。

## Ninja Adventure Asset Pack

- 作者：Pixel-boy、AAA。
- 来源：https://pixel-boy.itch.io/ninja-adventure-asset-pack
- 许可：CC0 1.0 Universal。
- 许可文件：`assets/ninja_adventure/LICENSE.txt`。
- 作者说明：`assets/ninja_adventure/README.md`。

本工程使用用户提供的原始素材副本。预览场景展示随包提供的 `Example 5 ( Old Version).png` 参考图。

## 游戏与摄像头运行环境

- Godot 4.7.2：MIT，源码与许可 https://github.com/godotengine/godot/tree/4.7.2-stable 。
- Python 3.12.10：PSF，安装包runtime内保留LICENSE.txt，https://www.python.org/downloads/release/python-31210/ 。
- Ultralytics 8.4.173：AGPL-3.0，源码 https://github.com/ultralytics/ultralytics/tree/v8.4.173 ，许可证保留于runtime/site-packages对应dist-info/licenses。此首版使用YOLO及其训练权重。
- Torch 2.14.1+cpu、Torchvision 0.29.1+cpu：BSD，源码 https://github.com/pytorch/pytorch/tree/v2.14.1 与 https://github.com/pytorch/vision/tree/v0.29.1 。
- OpenCV 5.0.0：Apache-2.0，Python wheel额外许可见runtime/site-packages/opencv_python-*.dist-info/LICENSE*。
- Microsoft Visual C++ Runtime：微软可再发行组件，应用本地运行DLL随独立推理环境提供。

其余依赖的准确版本见packaging/windows/runtime-requirements.txt；各wheel自带的许可证与声明在runtime/site-packages中保留。首版模型训练数据与来源记录见training/gifts/README.md及pipeline；原图片不放进源码仓库或安装包。
