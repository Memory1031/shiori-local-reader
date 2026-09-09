import '../../domain/contracts/contracts.dart';
import '../../domain/contracts/local_book_decoder.dart';
import '../../domain/models/models.dart';

/// Local-only reading assembly. Keys outside the local source have no backing
/// implementation and fail explicitly; borrowed dependencies keep their owners.
class LocalReadingRepository
    implements
        NovelRepository,
        LocalNavigationRepository,
        LocalPagePresentationRepository,
        LocalBookInvalidation,
        LocalContentLinkRepository {
  LocalReadingRepository({required this.local});
  final LocalBookStore local;
  @override
  Stream<NovelKey> get invalidations => local is LocalBookInvalidation
      ? (local as LocalBookInvalidation).invalidations
      : const Stream.empty();

  @override
  Stream<NovelKey> get changes => local is LocalBookInvalidation
      ? (local as LocalBookInvalidation).changes
      : const Stream.empty();

  @override
  Future<Result<String?>> loadPagePresentation(
    ChapterKey chapter, {
    required CancellationToken cancellation,
  }) async {
    if (!_local(chapter.novelKey) ||
        local is! LocalPagePresentationRepository) {
      return const Success(null);
    }
    return (local as LocalPagePresentationRepository).loadPagePresentation(
      chapter,
      cancellation: cancellation,
    );
  }

  // Legacy shelf entries from builds with online sources are not readable
  // here. They stay stored and removable; reads report notFound instead of
  // blocking or crashing local reading.
  AppFailure _absent(Operation op) => AppFailure(
    kind: FailureKind.notFound,
    operation: op,
    retryPolicy: RetryPolicy.never,
  );

  bool _local(NovelKey key) => key.sourceId == LocalBookIdentity.sourceId;
  Future<Result<LoadResult<T>>> _read<T>(
    NovelKey key,
    Operation op,
    CancellationToken token,
    T? Function(LocalBookRecord) select,
  ) async {
    final result = await local.read(key, cancellation: token);
    if (result case Failure(:final failure)) return Failure(failure);
    final record = (result as Success<LocalBookRecord?>).value;
    final value = record == null ? null : select(record);
    if (value == null) {
      return Failure(AppFailure(kind: FailureKind.notFound, operation: op));
    }
    return Success(
      LoadResult(
        value: value,
        origin: LoadOrigin.local,
        fetchedAt: record!.importedAt,
      ),
    );
  }

  @override
  Future<Result<LoadResult<NovelDetail>>> loadDetail(
    NovelKey key, {
    required ReadMode mode,
    required CancellationToken cancellation,
  }) => _local(key)
      ? _read(key, Operation.novelDetail, cancellation, (r) => r.content.detail)
      : Future.value(Failure(_absent(Operation.novelDetail)));
  @override
  Future<Result<LoadResult<Catalog>>> loadCatalog(
    NovelKey key, {
    required ReadMode mode,
    required CancellationToken cancellation,
  }) => _local(key)
      ? _read(key, Operation.catalog, cancellation, (r) => r.content.catalog)
      : Future.value(Failure(_absent(Operation.catalog)));
  @override
  Future<Result<LoadResult<ChapterContent>>> loadChapter(
    ChapterKey key, {
    required ReadMode mode,
    required CancellationToken cancellation,
  }) => _local(key.novelKey)
      ? _read(
          key.novelKey,
          Operation.chapter,
          cancellation,
          (r) => [
            ...r.content.chapters,
            ...r.content.auxiliaryChapters,
          ].where((c) => c.key == key).firstOrNull,
        )
      : Future.value(Failure(_absent(Operation.chapter)));
  @override
  Future<Result<List<LocalContentLink>>> loadContentLinks(
    ChapterKey source, {
    required CancellationToken cancellation,
  }) async {
    final result = await _read(
      source.novelKey,
      Operation.chapter,
      cancellation,
      (r) => r.content.links.where((l) => l.source == source).toList(),
    );
    return switch (result) {
      Success(:final value) => Success(value.value),
      Failure(:final failure) => Failure(failure),
    };
  }

  @override
  Future<Result<List<ChapterKey>>> loadReadingOrder(
    NovelKey book, {
    required CancellationToken cancellation,
  }) async {
    final result = await _read(
      book,
      Operation.catalog,
      cancellation,
      (r) =>
          r.content.readingOrder ??
          r.content.chapters.map((c) => c.key).toList(),
    );
    return switch (result) {
      Success(:final value) => Success(value.value),
      Failure(:final failure) => Failure(failure),
    };
  }

  @override
  Future<Result<List<LocalNavigationEntry>>> loadNavigation(
    NovelKey key, {
    required CancellationToken cancellation,
  }) async {
    final result = await _read(
      key,
      Operation.catalog,
      cancellation,
      (r) => r.content.navigation.isNotEmpty
          ? r.content.navigation
          : [
              for (final c in r.content.chapters)
                LocalNavigationEntry(title: c.title, chapterKey: c.key),
            ],
    );
    return switch (result) {
      Success(:final value) => Success(value.value),
      Failure(:final failure) => Failure(failure),
    };
  }

  @override
  Stream<Result<LoadResult<NovelDetail>>> detailUpdates(NovelKey key) =>
      _local(key)
      ? changes
            .where((k) => k == key)
            .asyncMap(
              (_) => loadDetail(
                key,
                mode: ReadMode.cacheOnly,
                cancellation: CancellationSource().token,
              ),
            )
      : const Stream.empty();
  @override
  Stream<Result<LoadResult<Catalog>>> catalogUpdates(NovelKey key) =>
      _local(key)
      ? changes
            .where((k) => k == key)
            .asyncMap(
              (_) => loadCatalog(
                key,
                mode: ReadMode.cacheOnly,
                cancellation: CancellationSource().token,
              ),
            )
      : const Stream.empty();
  @override
  Stream<Result<LoadResult<ChapterContent>>> chapterUpdates(ChapterKey key) =>
      _local(key.novelKey)
      ? changes
            .where((k) => k == key.novelKey)
            .asyncMap(
              (_) => loadChapter(
                key,
                mode: ReadMode.cacheOnly,
                cancellation: CancellationSource().token,
              ),
            )
      : const Stream.empty();

  // No online sources exist in this build; search and discovery have no
  // implementation to delegate to.
  @override
  Future<Result<List<DiscoverSection>>> discover(
    SourceId id, {
    required CancellationToken cancellation,
  }) => Future.value(
    Failure(
      AppFailure(kind: FailureKind.unsupported, operation: Operation.discover),
    ),
  );
  @override
  Future<Result<SearchPage>> search(
    SourceId id,
    String query, {
    SearchCursor? cursor,
    required CancellationToken cancellation,
  }) => Future.value(
    Failure(
      AppFailure(kind: FailureKind.unsupported, operation: Operation.search),
    ),
  );
}
