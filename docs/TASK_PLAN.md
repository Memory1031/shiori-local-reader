# 当前维护计划

更新：2026-09-09。

## 已完成

- 统一书签图标、首页字标与 Android / iOS 图标资源。
- 配置 Apache-2.0 许可证，补齐第三方许可和品牌来源说明。
- 完成源码、配置及文档审查，验证结果见下方。

## 待办

- 审核 1.0.0+1 更新说明及 dev.shiori.localreader 应用标识。
- 确认签名配置。
- 完成 Android 最终签名安装包验证。
- 完成 iOS 独立应用标识版本的真机安装，检查启动、导入、阅读及分享扩展。
- 按 develop 开发、master 发布、tag 触发构建的流程发布。

## 支持范围

EPUB/TXT 格式支持和排版限制见[本地导入](local-import.md)，阅读交互见[阅读器](reader.md)。

## 当前验证状态

2026-09-09：完整离线测试 422 项、Python 发布工具测试 6 项、格式、静态分析及生成一致性检查通过。应用标识调整后补跑 10 项导入测试通过，Android Release 与 iOS 无签名 Release 构建通过；包内标识为 `dev.shiori.localreader`，主应用及 iOS 分享扩展版本均为 `1.0.0+1`。

最终真机安装、正式签名产物及远端 Actions 尚待验证。本机 Android SDK annotations.zip 有损坏警告，未阻止构建。
