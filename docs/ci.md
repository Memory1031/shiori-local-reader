# 持续集成与发布

## 日常检查

PR、推送 develop、手动触发 [ci.yml](../.github/workflows/ci.yml)：格式、静态分析、锁文件、数据库及本地化生成一致性。按项目约定，单元 / 组件测试在本地提交前执行，CI 绿色不代表 UT 已执行；日常不构建 APK。

Flutter 固定 3.38.4，两份锁文件使用 `PUB_HOSTED_URL=https://pub.flutter-io.cn`。根项目与 `tool/db_codegen` 都需严格安装依赖。

## tag 发布

develop 开发，master 为发布分支；只有推送 `v*` 标签运行 [release.yml](../.github/workflows/release.yml)。工作流检查工具及版本、准备签名、构建正式入口 `lib/main.dart`，核验 APK 签名 / 包名 / 版本及不可调试属性后上传。不会等待或重复日常 CI；创建标签前完成本地测试及对应提交的质量检查。

`release_android.py` 固定使用 Build Tools 35.0.0。签名通过四项仓库 secrets 注入，失败不上传，始终清理临时密钥。仅发布 job 拥有 contents:write，不在 PR 注入签名 secrets。

产物：`shiori-local-reader-<tag>-android.apk`、`SHA256SUMS.txt`、`release-info.json`。已有 Release 重跑会更新附件；无对应 release notes 时使用 GitHub 自动说明。当前没有 iOS CI 发布链路。

结构检查运行 `dart tool/check_ci_yaml.dart`，Python 发布回归运行 `python3 -m unittest discover -s tool -p 'test_release_android.py'`。

## 发布操作

Android 仓库 secrets：`ANDROID_KEYSTORE_BASE64`、`ANDROID_STORE_PASSWORD`、`ANDROID_KEY_ALIAS`、`ANDROID_KEY_PASSWORD`。密钥独立备份，不提交到 Git。本地没有 key.properties 时 Release 构建可能使用 Debug 签名，发布前需核验正式签名。iOS 使用本地开发者账户签名，无 CI 发布链路。

版本预演、发版核对清单、发布步骤与发布后验收见[发布操作](release/README.md)。
