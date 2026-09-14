# 跨层契约与资源所有权

契约使用纯 Dart 模型，平台适配由 data / presentation 层承担。`NovelSource` / `SourceMedia` 等通用契约用于开发 fixtures 与测试。入口 `lib/domain/contracts/contracts.dart`。

## Result、失败和取消

`Result<T>` 是 sealed Success<T> / Failure<T>，以 switch 解构或 map 处理；Success(null) 与 Failure 明确不同，void 操作使用 Success<void>(null)。返回 Future 的操作及各数据流的预期失败都通过 Result 传递；数据层负责拦截、映射原始传输 / 文件 / SQL 异常，不让 server message、cause、stack 跨边界。构造参数不合法或已关闭资源继续使用属于调用方编程错误，不伪装成失败。

AppFailure 包含 FailureKind、Operation、RetryPolicy、可选本地 diagnosticId、FailureContext 和可选 retryNotBefore。context 是供 UI 本地化的封闭枚举，不接受任意文本；diagnosticId 限定本地生成的 32 位小写十六进制关联 ID，不得取自外部输入。

- 本地读取的稳定结果使用 notFound / unsupported / parse / database / cache 等 kind；unsupported、cancelled、tooLarge、accessRestricted 必须 never。
- cancelled 不作为刷新失败 badge 或弹窗；UI 丢弃已过时请求的结果。AppFailure 没有 raw message / URL / Header / exception 字段。

调用方创建 CancellationSource，只向下传递 token；cancel 幂等，token 提供同步 isCancelled 和异步 whenCancelled，无失败消息。操作开始前必须检查 token，在返回 / 发布晚结果前再次检查。读取取消返回 Failure(cancelled)；写入在提交前可取消，提交已发生则返回真实提交结果，不能声称取消而隐藏已发生的写入。

取消是协作协议，不是 Future.any 自动中断 IO 的承诺。数据实现须绑定底层流取消，并在操作完成时清理关联；调用方结束操作或销毁页面时 cancel 自己持有的 source。共享 in-flight 的每个调用者有独立 token，一个调用方取消不终止其他消费者。

## NovelSource（仅开发 fixtures 实现）

SourceDescriptor 同步描述 sourceId、displayName、supportsDiscover、supportsSearchPaging，不触发会话。NovelSource 的 discover、search、getNovelDetail、getCatalog、getChapter 均为异步 Result，并要求 CancellationToken。该契约由 `lib/dev/` 的内存 fixtures 与 `test/support/contract_fakes.dart` 行为测试使用。

SearchCursor 只包含 sourceId 和 opaqueValue。SearchPage 复制 items，拒绝重复 NovelKey、跨源 items / cursor；nextCursor=null 表示终止，空页必须终止。DiscoverSection 只有 label 与不可变 items；不支持 Discover 返回 Failure(unsupported)，不能把未实现冒充合法空结果。

## NovelRepository

生产装配为 `LocalReadingRepository`：仅实现 `local` SourceId 的读取与更新；discover / search 返回 unsupported，非 `local` 键返回 notFound。查询接口接收 SourceId；detail / catalog / chapter 接收现有 Key，以 `Future<Result<LoadResult<T>>>` 返回。LoadResult 的 value、origin(memory/local/remote)、UTC fetchedAt、isStale、refreshFailure 都是一次观察的固定字段；T 须为不可变领域值，媒体 lease 的生命周期是明确例外。本地实现忽略 ReadMode（本地读取无远程路径），origin 恒为 local。

刷新通知固定为按 Key 的 `detailUpdates` / `catalogUpdates` / `chapterUpdates`：广播、无初始事件、订阅本身无 IO，事件类型与对应 load 返回类型相同，预期失败是数据而非 Stream.addError(rawException)。Controller 必须先订阅再 load，销毁时 cancel 订阅；仓库发出新值而非偷偷修改旧对象。

## SourceMedia 与 ImageRepository 所有权

`SourceMedia.openMedia(ref, maxBytes, cancellation)` 返回 Result<SourceMediaBody>，maxBytes 必须为正。实现必须按实际累计字节限制完整流，不能只相信 Content-Length；元数据 MediaInfo 只包含格式、可选长度 / 尺寸，未知值为 null / unknown。生产无在线媒体；本地书籍媒体由 LocalBookStore 的 readMedia 提供。

SourceMediaBody.chunks 是单消费者 `Stream<Result<List<int>>>`，成功块不可修改，累计不超过 maxBytes；读取失败、超限或取消发出一次终止 Failure，然后结束。成功获得 body 后消费者即拥有关闭责任，即便从未订阅也必须 finally close；重复 close 均须安全。close 不抛原始 cleanup 异常。

`ImageRepository.load(ref, mode, cancellation)` 返回 `Result<LoadResult<MediaLease>>`：

- MediaData 为 MemoryMedia（复制并只读的 Uint8List）或 LocalMedia（已验证 App 私有路径），不含 ImageProvider / File / Widget。Flutter 适配放 presentation。
- 每次成功加载交付独立 lease，消费者 finally close；close 只释放自己的内存引用 / 文件 pin，不影响其他 lease。关闭后不能继续使用其 data。
- persistence 独立于 LoadOrigin：内存结果不能自称已落盘。`LocalImageRepository` 从已持久化的托管文件读取，persistence 为 persistedLocal；非 local 来源的 ref 返回 notFound。

媒体 lease 不经广播通知传递，每个 load 单独交付所有权，避免多个订阅者误用同一可关闭资源。

## LibraryRepository 与 SettingsStore

LibraryRepository 是书架和阅读历史唯一写入口，所有操作本地完成。watchBookshelf / watchRecentReading 发初始及后续不可变完整快照；排序使用最近阅读 / addedAt 降序和稳定键 tie-break。订阅者持有并取消自己的数据库监听。

putBookshelf 按 NovelKey 幂等，保留既有 addedAt；removeFromBookshelf 返回被移除条目，底层只删除书架记录、保留进度。本地书移除改走 LocalBookManagement.deleteBook，确认后删除托管文件、索引、书架和进度并失效旧写；不使用仅删书架的接口。文件清理延后时明确提示 cleanupPending。getProgress 无记录为 Success(null)。clearHistory 单独删除历史，不影响书架，且使在途旧进度代次失效，避免晚写复活历史。

进度晚写保护使用 `beginProgressSession(NovelKey) → Result<int>` 与 `ProgressWriteStamp(generation,sequence)`：仓库生成每本书跨进程单调代次，调用方在同代次递增 sequence；saveProgress 原子检查 stamp 并写入。返回 true 表示已提交，false 表示旧代次 / 重复 / 倒序写被忽略，不能当作已保存。代次与正文 revision、时间戳无关，不塞进 ReadingProgress 实体。

SettingsStore.load/save 使用 ReaderSettings；取消前提交规则同上。存储层遇坏存储 codec / 未知版本可按既定策略回退默认设置并记录安全诊断，不重置无关书架 / 进度，实际写失败返回 Failure(database/cache)。

## 本地能力

ImportSource 只接收候选副本：不透明 ID、显示名、字节大小、封闭错误码及进度事件；pending 返回有序待确认回执列表，是重启恢复依据。acknowledge(id) 是按 ID 幂等的确认消费回执，只消费指定回执，不影响其他项；cancelCopy 等待 Native 接收结束（复制、流关闭与暂存清理完成）后才返回，不在写入尚未停止时声称完成。回执对应的路径与平台文件结构保留在 native / data 层私有，不进入 ImportCandidate 或领域模型。Native 批次发布是原子的：任一复制失败或取消不暴露部分回执；该原子性不改变此后 Dart 逐书入库可部分成功的语义。平台入口、目录结构与 durable inbox 协议见[本地导入](local-import.md#平台接收)。

PlatformImportSource 完整验证两平台 List<Map> 或 legacy Map/null 后才替换 ID → path 缓存，malformed 响应报告 storage 并保留旧绑定；路径不进入 ImportCandidate。ImportProblem.batchLimit 只表示原生选择 / 接收超过批量上限（项数或整批实际字节数，限额见[本地导入](local-import.md#公共收件箱协议)），单文件超限仍使用 tooLarge；不扩大控制器 fatal policy，也不增加进度事件字段。

导入控制器按回执顺序严格串行处理：单文件失败只标记该项并继续；storage / parserUnavailable 视为全局失败停止后续项；成功项提交后立即按 ID ack 并从 inbox 删除，失败与未处理回执保留待重试（dedup 命中仍视为成功）。「停止导入」停止当前处理，不回滚已成功项、不 ack 未完成回执；非运行态的「取消 / 放弃导入」显式放弃当前批次，逐条 ack 并 discard 剩余 inbox 副本，不删除用户原文件或已入库书籍。取消清理期间禁止重新选择或提交；部分 ack 失败只移除已 ack 项，保留剩余项和 storage 错误供重试；旧 pending 查询不得重新加入已取消回执。

LocalBookDecoder 接收导入 session、格式、文件名、token 和编码确认回调，严格解码后才提供有界预览。LocalBookStore 唯一负责发布，生产使用 addToShelf 同事务加入书架；LocalBookManagement 删除后失效旧会话，cleanupPending 表示 SQL 已提交但文件待回收。

LocalNavigationRepository 返回嵌套目录与 ChapterKey / 可选 blockKey。LocalPagePresentationRepository 为特殊短页提供可选惰性静态 HTML，普通正文返回空；领域正文仍保存原生语义块，不持有 WebView 对象。发布与兼容见[本地导入](local-import.md)。

应用根先关闭导入控制器，再关闭媒体 / 书籍仓库与数据库。ReaderPreferences 读取或更新时将旧 scroll 归一化为 paged，保留排版；读取不为了模式迁移主动覆盖存储。详见[阅读器](reader.md)与[数据库](architecture.md)。

## 显式重解析

LocalBookReparse 接收书籍 Key、编码选择回调/可选 override 与 cancellation；返回 LocalReparseResult（approximate、cleanupPending）。失败前旧版本保持可读，提交后成功优先于取消；新旧正文及进度经同一 SQL 事务发布。LocalBookInvalidation 的 invalidations 在维护开始退役旧 Reader，changes 在提交后触发本地 detail/catalog/chapter 更新；两者广播、无初始事件，消费者取消订阅。

维护期间不发新进度会话，saveProgress 返回 false；clearHistory 仍生效并阻止使用旧快照发布。已重解析书的保存还校验 catalog/content revision，旧正文即使申请到新 generation 也不能覆盖迁移位置。位置迁移不保留像素提示，近似结果供 UI 明示。内容可选 txtEncoding 只属于本地解析元数据，不进入正文身份摘要。详见[结果与边界](local-import.md)。

## 书内链接与连续阅读合同

LocalContentLink 是独立于 ContentBlock 的不可变侧表项：来源 ChapterKey/blockKey、标签、可选目标 ChapterKey/blockKey，以及封闭 unavailable 原因；没有原始 URL/路径，不改变正文摘要。LocalBookContent 可保存 auxiliaryChapters、links 和可空 readingOrder；manifest 缺可选字段时 links/auxiliary 为空，readingOrder 默认为原目录顺序。

可点击范围使用 sourceOffset / sourceLength，均按来源块内 Unicode code points 计数；跨块链接逐块保存范围，不改正文。sourceOffset 非空且 sourceLength 为空的项兼容旧脚注合同，label 对应数字上标，并有可空 footnoteText（纯文本）。可用脚注的 target 指向来源章，面板直接消费 footnoteText，不进行章节导航；不可用项保留入口位置及原因。旧侧表缺范围字段时仍可通过菜单访问普通链接。解析器替换脚注入口并移除注释正文会正常产生新的正文 revision；交互本身不修改内容身份。

LocalContentLinkRepository 提供按来源章节的链接和主阅读顺序，所有请求仍携带取消 token。包内 href/fragment 在 data 层解析；远程、越界、缺文档或缺锚点只报告不可用，不能联网或错误地跳章首。同资源链接保留当前 occurrence，跨资源链接选择目标第一次出现。非 spine 的 manifest XHTML 可作为有界辅助文档加载；不进入主目录/连续阅读序列。

正文内链、结构化目录和“本章链接”复用目标导航：同章在原视口恢复块位置；readingOrder 内其他章节使用现有切章及进度会话；其余文档打开临时辅助阅读页（不注入 LibraryRepository），最多嵌套 8 层。辅助页的原 Reader 保持挂载，返回使用原页/原 occurrence。维护 invalidation 同时退役主页和辅助页。linear=no 仍可明确选择，但不参与连续翻章。
