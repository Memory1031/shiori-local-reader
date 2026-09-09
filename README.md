<div align="center">
  <img src="assets/branding/shiori-icon.png" alt="Shiori Logo" width="112" />
  <h1>Shiori</h1>
  <p>使用 Flutter 构建的本地 EPUB/TXT 小说阅读器 · Android / iOS · 中文 / English</p>
</div>

---

Shiori 是一款离线阅读器。书籍从设备文件导入，阅读进度、书架和排版偏好保存在应用本地。

> 项目采用 [Apache-2.0](LICENSE) 许可证。发布操作见 [CI 与发布](docs/ci.md)。

## 功能

- **本地书库** — 导入 TXT 与无 DRM 的流式 EPUB 2/3；支持系统文件选择器、「打开方式」和分享接收。相同字节自动去重，同名不同内容视为不同书籍。
- **书架与续读** — 网格 / 列书架、封面展示、继续阅读入口与阅读历史；进度按语义位置保存，重启后接着读。
- **目录与跳转** — EPUB 嵌套目录与页内锚点直接定位；TXT 按识别出的章节标题生成目录。
- **阅读与排版** — 点按或拖动翻页、连续切章；字号、行距、段间距、五档页边距与纸张主题可调，调整后按语义位置恢复。
- **重新解析** — 从应用内保存的原件重新解析已导入书籍，尽量保留阅读位置，近似恢复会明确提示；不需要删除重导。
- **书内链接** — EPUB 脚注 / 辅助文档通过「本章链接」临时打开，返回保留原位置。
- **外观与语言** — 浅色、深色、跟随系统与多种强调色；中文 / English 界面。

## 版本说明

[Shiori 1.0.0](docs/release/notes/v1.0.0.md) · [GitHub Releases](https://github.com/Memory1031/shiori-local-reader/releases)

## 使用方式

1. **添加书籍**：通过「更多 → 导入」选择 TXT / EPUB 文件，或从其他应用「打开 / 分享」到 Shiori 后在应用内确认。导入会在应用内保存一份托管副本。
2. **开始阅读**：点击书架或继续阅读入口；点按正文中间唤出工具栏，可打开目录、本章链接或调整排版。
3. **移除书籍**：在书架或详情中移除会删除应用内的托管副本与阅读进度，**外部原文件不受影响**。

### 阅读实现方式

- 普通正文（文字、图片、标题）使用 Flutter **原生分页**渲染。
- 少量 EPUB 特殊短页（扉页等带浮动、定位、竖排样式的短内容）在受限条件下使用**静态 WebView** 呈现：脚本关闭、外部请求禁用、资源内嵌。
- 应用并非完整 EPUB 标准实现：不支持 DRM、PDF、完整固定版式与完整 CSS 级联；CJK 排版为常规水平排版，不含高级竖排 / 网格排版。具体支持矩阵见[本地导入文档](docs/local-import.md)。

## 本地开发

使用固定的 **Flutter 3.38.4 / Dart 3.10.3**。Android 构建需要 JDK 17、SDK 36 和 NDK 28.2.13676358；iOS 构建需要 macOS / Xcode。

以下命令适用于已安装 FVM 的 macOS / Linux 环境：

```sh
fvm install 3.38.4
export PUB_HOSTED_URL=https://pub.flutter-io.cn
fvm flutter pub get --enforce-lockfile
fvm flutter devices
fvm flutter run --target lib/main.dart
```

离线测试、格式与静态分析、数据库生成本地检查命令见[开发说明](docs/development.md)。版本约束以 [.fvmrc](.fvmrc) 和 [pubspec.yaml](pubspec.yaml) 为准。

## 项目文档

| 文档 | 内容 |
| --- | --- |
| [文档导航](docs/README.md) | 架构、模块与维护文档入口 |
| [架构与数据规则](docs/architecture.md) / [接口合同](docs/contracts.md) | 领域身份、装配、存储与跨层契约 |
| [阅读器](docs/reader.md) / [本地导入](docs/local-import.md) | 阅读行为、格式兼容与使用限制 |
| [开发说明](docs/development.md) / [持续集成](docs/ci.md) | 环境准备、测试与质量检查 |
| [当前范围](docs/TASK_PLAN.md) / [验证状态](docs/TASK_PLAN.md#当前验证状态) | 待办事项与实际验证证据 |

## 问题反馈

注明应用版本、设备与系统版本、复现步骤、预期和实际表现，必要时附截图。EPUB 兼容性问题请尽量提供最小可复现样本或结构说明；不要上传密码、个人数据或无权分享的完整书籍。

## 隐私与许可

书架、进度、偏好和导入副本保存在应用本地。Android 系统备份 / 换机迁移可能包含这些数据。书籍由使用者自行导入；开发与测试采用固定 seed 的合成样本。

项目代码采用 [Apache-2.0](LICENSE)，第三方组件保留各自许可证。品牌由书签图标与 Shiori 字标组成，来源见[素材说明](assets/branding/README.md)；依赖许可清单见[发布文档](docs/release/dependencies.md)。
