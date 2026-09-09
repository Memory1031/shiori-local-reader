import 'package:flutter/material.dart';
import '../../app/routes.dart';
import '../../domain/contracts/contracts.dart';
import '../../domain/models/models.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/widgets/book_cover.dart';
import '../../shared/widgets/shiori_logo.dart';
import '../bookshelf/library_controller.dart';
import '../bookshelf/bookshelf_view.dart';
import '../bookshelf/library_observer.dart';
import '../bookshelf/remove_shelf_book.dart';
import '../history/history_screen.dart';
import '../reader/continue_reading.dart';
import '../novel_detail/detail_screen.dart';
import '../reader/book_reader_screen.dart';
import '../local_books/local_books_screen.dart';

class ReadingHome extends StatefulWidget {
  const ReadingHome({
    super.key,
    required this.repository,
    required this.library,
    this.images,
    this.settings,
    this.onAppearance,
    this.onImport,
    this.localBooks,
    this.localManagement,
    this.environmentLabel,
  });
  final NovelRepository repository;
  final LibraryRepository library;
  final ImageRepository? images;
  final SettingsStore? settings;
  final VoidCallback? onAppearance;
  final VoidCallback? onImport;
  final LocalBookStore? localBooks;
  final LocalBookManagement? localManagement;
  final String? environmentLabel;
  @override
  State<ReadingHome> createState() => _ReadingHomeState();
}

class _ReadingHomeState extends State<ReadingHome> {
  late final LibraryController _library;
  @override
  void initState() {
    super.initState();
    _library =
        LibraryController(widget.library, localBooks: widget.localManagement)
          ..onStart()
          ..addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _library.removeListener(_changed);
    _library.onDelete();
    _library.dispose();
    super.dispose();
  }

  late final AppRoutes _routes = AppRoutes(
    novel: (_, key) => LibraryObserver(
      controller: _library,
      builder: (context, library) => DetailScreen(
        novel: key,
        repository: widget.repository,
        images: widget.images,
        onTarget: (target) => _routes.open(
          context,
          ReaderDestination(target.chapterKey, blockKey: target.blockKey),
        ),
        onChapter: (chapter) =>
            _routes.open(context, ReaderDestination(chapter)),
        onRead: _continue,
        continueReading: library.progressFor(key) != null,
        isOnShelf: library.contains(key),
        actionFailure: library.writeFailure ?? library.shelfFailure,
        showPendingActions: false,
        onShelfSnapshot:
            !library.shelfReady ||
                library.shelfFailure != null ||
                library.writing
            ? null
            : (summary) async {
                if (!library.contains(key)) {
                  await library.add(summary);
                  return;
                }
                final removed = await removeShelfBook(
                  context,
                  library,
                  summary,
                );
                if (removed &&
                    key.sourceId == LocalBookIdentity.sourceId &&
                    context.mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              },
      ),
    ),
    continueReader: (_, key) => ContinueReadingScreen(
      novel: key,
      repository: widget.repository,
      library: widget.library,
      images: widget.images,
      settings: widget.settings,
      onDetails: _readerDetails,
    ),
    readerTarget: (_, key, block) => BookReaderScreen(
      initialBlockKey: block,
      startAtBeginning: key.novelKey.sourceId == LocalBookIdentity.sourceId,
      chapter: key,
      repository: widget.repository,
      images: widget.images,
      library: widget.library,
      settings: widget.settings,
      onDetails: _readerDetails,
    ),
  );
  void _readerDetails(NovelKey key) {
    Navigator.of(context).pushAndRemoveUntil<void>(
      _routes.route(context, NovelDestination(key)),
      (route) =>
          route.isFirst ||
          route is! PopupRoute &&
              !{'/reader', '/continue', '/novel'}.contains(route.settings.name),
    );
  }

  void _continue(NovelKey key) =>
      _routes.open(context, ContinueDestination(key));

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const ShioriLogo(),
        actions: [
          PopupMenuButton<String>(
            tooltip: strings.moreActions,
            onSelected: (value) {
              if (value == 'import') widget.onImport?.call();
              if (value == 'local') {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => LocalBooksScreen(
                      store: widget.localBooks!,
                      management: widget.localManagement!,
                      library: widget.library,
                      onRead: _continue,
                      onImport: widget.onImport!,
                    ),
                  ),
                );
              }
              if (value == 'appearance') widget.onAppearance?.call();
              if (value == 'history') {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => HistoryScreen(
                      controller: _library,
                      onContinue: _continue,
                    ),
                  ),
                );
              }
            },
            itemBuilder: (_) => [
              if (widget.onImport != null)
                PopupMenuItem(
                  value: 'import',
                  child: Text(strings.importTitle),
                ),
              if (widget.localManagement != null)
                PopupMenuItem(
                  value: 'local',
                  child: Text(strings.localBooksTitle),
                ),
              PopupMenuItem(
                value: 'history',
                child: Row(
                  children: [
                    Icon(
                      Icons.history_outlined,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Flexible(child: Text(strings.historyTitle)),
                  ],
                ),
              ),
              if (widget.onAppearance != null)
                PopupMenuItem(
                  value: 'appearance',
                  child: Row(
                    children: [
                      Icon(
                        Icons.palette_outlined,
                        size: 18,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                      Flexible(child: Text(strings.appAppearance)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (widget.environmentLabel != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Text(
                  widget.environmentLabel!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 840),
                  child: Column(
                    children: [
                      if (_library.recent.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              strings.detailContinue,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                        ),
                      if (_library.recent.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              title: Text(
                                _library.recent.first.snapshot.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                strings.readerChapterProgress(
                                  (_library
                                              .recent
                                              .first
                                              .position
                                              .chapterFraction *
                                          100)
                                      .round(),
                                ),
                              ),
                              leading: SizedBox(
                                width: 36,
                                child: BookCover(
                                  book: _library.recent.first.snapshot,
                                  images: widget.images,
                                ),
                              ),
                              trailing: const Icon(Icons.arrow_forward),
                              onTap: () =>
                                  _continue(_library.recent.first.novelKey),
                            ),
                          ),
                        ),
                      Expanded(
                        child: BookshelfView(
                          controller: _library,
                          images: widget.images,
                          onOpen: _continue,
                          onDetails: (key) =>
                              _routes.open(context, NovelDestination(key)),
                          onImport: widget.onImport,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
