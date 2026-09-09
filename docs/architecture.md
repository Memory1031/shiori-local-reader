# 架构与数据规则

更新：2026-09-09。应用围绕本地 EPUB/TXT 导入、阅读和持久化组织。本页维护领域身份、应用装配与存储资源规则；公共接口见[接口合同](contracts.md)。

## 领域模型与内容身份

领域层保持纯 Dart、不可变，不依赖 UI、网络、SQL 或平台。入口 `lib/domain/models/models.dart`，摘要实现 `lib/domain/content_identity.dart`。

### 模型边界

- 所有模型具有值相等语义；构造时复制集合，对外不可修改。运行时 hashCode 只服务内存集合，不可持久化。
- SourceId / NovelKey / ChapterKey / MediaRef 保留不透明字符串，不 trim、不拼 URL；拒绝空白 ID 和非法 Unicode。生产仅使用 `LocalBookIdentity` 的 `local` SourceId；Domain 不内置具体源常量。MediaRef 无 secret 的前提由数据层保证。
- Summary / Detail 以字符串列表表示作者和标签；缺少信息保留 empty / null / unknown，不猜作者、完结状态或时间。数据层负责 HTML entity / 标记清理，Domain 只接收普通文本；不因文本含 `<` 等合法字符便把它当 HTML 删除。
- Catalog 只持有不可变卷章树，flatChapters 是惰性视图；不按 ID 或标题排序。全目录 ordinal 必须从 0 连续递增；重复 groupId / ChapterKey、跨小说归属或卷归属错误直接拒绝。解析器先处理重复链接和缺名诊断，不能依赖 Domain 静默去重。无卷可用明确 isSynthetic 的分组，缺卷名为 null，由 UI 展示占位名。
- ChapterContent 接受 Paragraph / Image / Heading / Divider，保留段落顺序和单段完整文本。可读正文至少有一个非空 Paragraph 或 Image；纯图片章有效，只有空白 / 标题 / 分隔符无效。空 Paragraph 可在有效正文中表达已确认的语义空白。
- Paragraph 的 alignment 为 start / center / end，leadingIndent 为整数 0–8 em，表示段落首行缩进，不是整段左内边距；展示用前缀不计入原文位置。当前不启用 text runs / 嵌套 AST；EPUB 的 Ruby 降级为基字加括注、强调保留文字，不在 Domain 处理站点标签。
- 图片尺寸各自可未知；已知值须正数。封面和正文图片必须属于相同 Source。ImageBlock 尺寸为后续可发现的布局元数据，更新尺寸不改变 blockKey / contentRevision；mediaId、alt、caption 的改变会改变语义身份。
- ReadingProgress 持有 NovelSummary 快照以保留离线标题 / 封面，并检查 ChapterKey 与快照属于同一本书；是否收藏由独立 BookshelfEntry 表示。lastReadAt 统一为 UTC 毫秒，写入先后由持久化 sequence 控制。

### 摘要 v1 与序列化

固定输入为无额外空白的 JSON 数组：`["shiori",1,kind,fields]`，再按 UTF-8 编码、SHA-256 输出 64 位小写十六进制。fields 只允许字符串、整数、布尔值、null 和嵌套数组，拒绝 map / 浮点值，避免字段顺序和非有限数歧义。文本只将 CRLF / CR 统一为 LF；不 trim、不做 NFC/NFKC，不改变全角字符、标点、emoji、段内换行或首尾空白。拒绝孤立 UTF-16 surrogate，避免编码替换造成内容碰撞。

| 摘要 | 固定 fields 顺序 |
| --- | --- |
| Paragraph 语义 | text、alignment.name、leadingIndent |
| Image 语义 | `[sourceId, mediaId]`、alt、caption；不含 width / height |
| Heading 语义 | text、level（1–6）；非默认 alignment 追加参与身份，默认 start 保持旧格式 |
| Divider 语义 | 空数组 |
| blockKey（kind=block） | block kind、该类 semantic fields、同章该语义的 occurrence（从 0 开始） |
| contentRevision（kind=chapter） | title、按正文顺序排列的 blockKey 数组 |
| Catalog revision（kind=catalog） | `[sourceId, novelId]`，然后每个卷依次为 `[groupId,title,isSynthetic,章节数组]`；章节项为 `[[sourceId,novelId,chapterId],title,ordinal]` |

ChapterContent 统一重新分配 occurrence，不信任调用方手填值。不同语义块的插入不改变既有块键；在同样内容的重复块之前插入另一个相同块会改变后续 occurrence，这是规则的明确限制。blockKey 只在章节内使用；纯文本内容完全相同的不同章节可以得到相同摘要，业务定位始终同时使用 ChapterKey。

ChapterContent 提供 toJson / fromJson；读取时校验 normalizationVersion、块类型、blockKey、occurrence 和 contentRevision。JSON 返回的是独立容器，改动它不会修改值对象。存储 envelope 的 parserVersion、cache codec version、抓取时间不进入 Domain 摘要；其他模型由存储层 codec 负责。ReaderSettings 当前为 schemaVersion=3；读取 v1 / v2 保留原数值与阅读明暗，v1 补 paged，旧版统一补 paper=paper、controlsHintSeen=false。未知版本仍拒绝。

字号、屏宽、DPR、主题、pixelOffset、layoutKey、临时渲染切片都不进入正文摘要或序列化。一个极长 Paragraph 始终一个语义块，presentation 可临时切片但不能回写 Domain。

测试中的固定向量由 .NET `SHA256.HashData` 对手写精确 UTF-8 JSON 独立计算，包含 paragraph 语义、重复块 0/1、image、chapter 和 catalog。`tool/domain_example.dart` 在两个实际 Dart 子进程中输出完全一致，Windows 的输入/输出编码显式指定 UTF-8。

### 阅读位置与设置

ReaderPosition 的 blockIndex 非负，blockFraction / chapterFraction 必须有限且位于 0..1；NaN / Infinity / 越界直接拒绝，不静默改写错误进度。fractionFor 依 `(blockIndex + blockFraction) / blockCount` 计算，检查 index 属于本章；空内容仅允许 0/0 起点。文本 fraction 按 Unicode code point 偏移定义，UTF-16 布局索引转换留 presentation。构造位置时尚无正文实例，不假装已验证 blockKey 在某章内存在；实际恢复由阅读器处理。

像素提示必须同时包含合法 pixelOffset 和 layoutKey，仅用于同布局提示，不能替代语义位置。ReaderSettings 当前 schemaVersion=3，默认字号 20、行高 1.6、段间距 20、horizontalPadding 默认存储值为 30，对应适中档，每侧显示边距以 30 logical px 为基准；有效历史排版保留，未知版本拒绝。ReaderMode.scroll 只保留兼容解码，生产偏好层归一化为 paged，详见[阅读器](reader.md)。

AppSettings 独立 schemaVersion=2，包含 system / light / dark 和 teal / blueGrey / warmBrown / softPink；旧 v1 补默认青绿，不借用阅读主题。ReaderPaper 表示阅读纸色，controlsHintSeen 记录提示已确认；恢复默认保留该提示状态。所有值模型不含 Flutter Color 或语言文案。

### 本地模型

本地书籍以原文件 SHA-256 标识，章节使用稳定解析定位符。LocalNavigationEntry 独立保存嵌套目录与可选 blockKey，不改变 Catalog 章顺序；LocalBookInfo / LocalBookDeletion 描述管理结果，不暴露平台路径。规则见[本地导入](local-import.md)。

模型与摘要测试位于 `test/domain/`；`fvm dart tool/domain_example.dart` 使用自制内容演示跨进程确定性。

### 本地重解析位置

`migrateLocalPosition` 是纯 Dart 确定性迁移，输出不可变进度与 approximate 等级。使用章节/块身份、唯一文本/图片语义、受限邻近窗口，无法唯一匹配时回退比例/邻章并标记近似。跨块匹配按 code points；所有重解析位置清 layoutKey/pixelOffset，近似位置不保留 completed。EPUB 3 资源首次章键兼容旧规则，后续 occurrence 使用独立摘要 kind，与媒体资源身份分离。见[重解析规则](local-import.md)。

本地链接侧表与主阅读顺序仅属于本地书籍元数据；正文块文本及 blockKey/contentRevision 不因新增链接交互变化。辅助文档仍使用 ChapterContent 和本地资源身份，但不伪装成 spine occurrence 或推进主阅读进度。缺失目标必须为显式不可用项；不存储原始 URL 供 presentation 解释。

## 应用结构

### 页面与行为

正式入口为 `lib/main.dart`，组合根负责初始化本地存储、偏好、导入订阅和本地书籍仓库，不构造任何在线服务；开发入口为 `lib/main_dev.dart`，不进入生产依赖图。

首页展示书架与继续阅读。顶部展示品牌图，保留更多菜单；导入在更多菜单中。继续阅读使用本地进度，书架封面统一 2:3 容器、完整显示图片，标题行数不改变封面尺寸。本地书在书名下方以小号次要文字标记“本地 · EPUB / TXT”，网格和列表一致；格式信息尚未就绪时显示“本地”。本地书移除先确认，再删除应用内文件和进度，详情成功后返回首页。

详情展示简介、书架操作和目录；真实分组与合成无卷分组保持区别，目录顺序来自领域快照。详情页刷新等效于从托管文件重读本地记录。

阅读入口汇集本地书籍；本地 EPUB 目录可按嵌套条目 / fragment 直接定位。继续阅读和历史使用语义位置。具体规则见[阅读器](reader.md)、[本地导入](local-import.md)。

### 状态与资源所有权

Presentation 依赖领域契约，通过显式注入获得服务。应用根拥有共享 Repository、图片缓存与数据库；页面只关闭自己创建的请求、订阅、会话和 lease，不关闭借用的共享服务。

请求切换使用取消及代次判断，旧响应不能覆盖新查询或已销毁页面。Controller 订阅更新流后再发起加载；共享流不因一个页面退出而关闭。应用关闭时先关闭导入控制器，再关闭数据库，详见[契约](contracts.md)。

### 外观与本地化

应用外观和阅读器纸张 / 排版分开存储。应用支持跟随系统、浅色、深色，强调色包括青绿、蓝灰、暖棕、淡粉；阅读器设置独立见[阅读器](reader.md)。

用户文案统一维护在 `lib/l10n/app_zh.arb`、`app_en.arb`，使用 `AppLocalizations`；修改后运行 `fvm flutter gen-l10n` 并提交生成文件。内容标题不作为 UI 翻译，错误展示使用本地化 Failure 映射。

页面保留 SafeArea、可读语义标签与足够触控区域，关注小屏、横屏、大字和英文长度。iOS 路由遵循平台返回方式；自动化语义测试不能替代 TalkBack / VoiceOver 设备验证。

## 数据库与用户数据保护

### 当前存储

| 位置 | Schema | 内容 |
| --- | --- | --- |
| `users/users.sqlite` | v4 | bookshelf、reading_progress、progress_sessions、prefetch_choices、prefetch_settings、local_books、local_chapter_revisions（prefetch 两表仅用于 schema 兼容） |
| 平台 preferences | 独立 codec | readerSettings v3、appSettings v2 |
| `users/books/` | manifest v1 | 本地书托管原件、语义正文索引与媒体 |

AppPaths 通过 path_provider 解析 ApplicationSupport / temporary，固定 `shiori/production` 或 `shiori/development` 子目录。机器绝对路径和 URL 不进入持久身份。

LocalDatabases.open 打开用户库并以 NativeDatabase.createInBackground 建立后台连接；应用根拥有数据库，Repository 借用。运行期复用连接，不逐页 open。localBooks 管理器负责文件回收，先关闭管理器，再关库。

### 事务与 codec

Library 写入由事务串行执行；重复收藏保留首次 addedAt，移除书架保留历史。书架按最近阅读时间（无历史时 addedAt）降序，平局按 Source / Novel 键排序。watch 返回初始及后续不可变快照。

beginProgressSession 原子递增 generation 并重置 sequence；saveProgress 只接受当前 generation 和严格递增 sequence，旧写返回 false。clearHistory 推进 generation 并保留会话保护行，防止晚响应恢复已清历史。提交前取消可回滚，提交后返回真实结果。

preferences 使用独立 JSON key，Store 串行写入，读取等待已排队写入。坏 JSON、未知版本或非法数据返回默认与安全诊断，读操作不覆盖坏值 / 未来版本。偏好不承诺与 SQLite 跨存储事务。

### 迁移与生成

当前数据库使用 schema v4。v1～v4 快照用于迁移回归测试。schema、记录 codec、parser 版本、偏好版本、进度 generation 互不替代。

升级 DDL、完整性检查和 user_version 同事务提交；失败回滚，损坏或未知未来版本保留原文件并报错。不提供自动删用户库、drop/recreate 或生产 reset 来绕过故障。旧快照不能被当前 schema 重新导出覆盖。

运行时 Drift 2.32.1 / sqlite3 3.5.2；生成器独立在 `tool/db_codegen`，避免 analyzer 与固定 Flutter 工具链冲突。安装工具锁定依赖后：

```sh
bash tool/generate_database.sh
fvm flutter test --no-pub test/data/local
```

Windows 用 `tool/generate_database.ps1`。生成 `.g.dart` 与 schema 快照一并评审，CI 检查 diff 及新增快照。

### 备份与恢复

Android XML 排除开发目录、导入暂存及 `disposable/`，用户数据可参与系统备份 / 换机。iOS 尚未完整验证缓存排除属性；目录分开本身不证明不会备份。系统备份恢复和整机磁盘耗尽尚未实测。

排障先退出应用，保全数据库、WAL / SHM、preferences、托管原件及 manifest，在副本上检查；不以卸载或删库作为默认恢复步骤。本地文件发布协议见[本地导入](local-import.md)。

### 重解析发布

v4 包含活动 bundle、解析版本、维护标记及章节版本索引；active_bundle=NULL 时读取根 manifest。重解析切换活动文件指针、位置及 generation 使用一个事务；文件先就绪再提交，未引用文件由管理器恢复清理。维护标记重启后解除；坏活动 manifest 不触发旧文件删除。详见[重解析规则](local-import.md)。

## 图片与内存缓存

每次加载返回独立 `MediaLease`，消费者必须关闭；不能广播同一 lease 给多个页面。`LocalImageRepository` 从托管文件读取并交付只读字节，不访问网络；解码与展示缓存由 presentation 层的有界实现负责，见[契约](contracts.md)。

`MemoryImageRepository`（有界并发、编码内存预算与空闲 LRU）仅用于开发场景与探针，按 `SourceMedia` 解析回调取数，不属于生产装配。
