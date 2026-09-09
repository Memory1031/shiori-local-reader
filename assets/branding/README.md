# Shiori 品牌素材

品牌由鼠尾草绿色折页书签和 Shiori 字标组成。

| 文件 | 用途 | 来源 |
| --- | --- | --- |
| `shiori-icon.png` | 应用图标与启动页 | 2026-09-09 使用 OpenAI 图像生成工具，根据文字描述生成 |
| `../brand/shiori.png` | 首页字标 | 使用 OpenAI 图像生成工具制作的 Shiori 字标与抽象书签组合 |

## 许可证

上述品牌图片及由其生成的 Android / iOS 图标、启动图采用 [Apache-2.0](../../LICENSE) 许可证。素材来源见上表；商标使用按该许可证第 6 条处理。

图标设计描述：暖白背景、鼠尾草绿色、单个折页书签、简洁几何轮廓。

运行 `python3 tool/update_app_icons.py`（macOS，系统 sips）或 `./tool/update-app-icons.ps1`（Windows）更新 Android / iOS 全部桌面图标和启动图。应用启动页使用同一主图，首页使用独立字标。原生图标在重新构建安装后生效。
