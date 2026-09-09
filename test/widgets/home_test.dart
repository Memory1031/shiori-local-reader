import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/app/app.dart';
import 'package:shiori/app/routes.dart';
import 'package:shiori/dev/fixtures.dart';
import 'package:shiori/domain/contracts/contracts.dart';
import 'package:shiori/features/home/reading_home.dart';
import 'package:shiori/domain/models/models.dart';
import 'package:shiori/l10n/generated/app_localizations.dart';

void main() {
  for (final locale in ['en', 'zh']) {
    testWidgets('$locale narrow large text keeps home usable', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final env = FixtureEnvironment();
      await env.library.putBookshelf(
        BookshelfEntry(
          snapshot: env.source.data.summary(FixtureScenario.longTitle),
          addedAt: DateTime.now(),
        ),
        cancellation: CancellationSource().token,
      );
      await tester.pumpWidget(
        ShioriApp(
          locale: Locale(locale),
          homeBuilder: (context, _) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: ReadingHome(
              repository: env.novels,
              library: env.library,
              environmentLabel: AppLocalizations.of(context).offlineEnvironment,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // The online search entry is gone; the menu holds import and history.
      final search = locale == 'zh' ? '搜索' : 'Search';
      expect(find.byTooltip(search), findsNothing);
      await tester.scrollUntilVisible(
        find.byKey(
          ValueKey(env.source.data.summary(FixtureScenario.longTitle).key),
        ),
        100,
        scrollable: find.descendant(
          of: find.byKey(const PageStorageKey('shelf-grid')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.longPressAt(
        tester.getTopLeft(
              find.byKey(
                ValueKey(
                  env.source.data.summary(FixtureScenario.longTitle).key,
                ),
              ),
            ) +
            const Offset(30, 30),
      );
      await tester.pumpAndSettle();
      final remove = locale == 'zh' ? '移出书架' : 'Remove from bookshelf';
      await tester.tap(find.text(remove));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(env.source.controls.calls, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.runAsync(env.close);
    });
  }
  testWidgets('empty home is local first and offers import', (tester) async {
    final env = FixtureEnvironment();
    await tester.pumpWidget(
      ShioriApp(
        locale: const Locale('en'),
        routes: AppRoutes(
          home: (_) => ReadingHome(
            repository: env.novels,
            library: env.library,
            onImport: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(env.source.controls.calls, isEmpty);
    expect(find.text('Your bookshelf is empty.'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Discover'), findsNothing);
    expect(find.byTooltip('Search'), findsNothing);
    expect(find.byIcon(Icons.file_download_outlined), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await tester.runAsync(env.close);
  });
}
