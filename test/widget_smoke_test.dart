/// Structural smoke tests: the shell boots, core screens render their
/// design-critical elements, and navigation reaches session setup.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rallycoach/app/providers.dart';
import 'package:rallycoach/app/router.dart';
import 'package:rallycoach/app/theme.dart';
import 'package:rallycoach/core/storage/database.dart';
import 'package:rallycoach/features/session_setup/setup_screen.dart';
import 'package:rallycoach/shared/widgets/rc_widgets.dart';

Widget _app(AppDatabase db) => ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
      ],
      child: MaterialApp.router(
        theme: buildRallyCoachTheme(),
        routerConfig: buildRouter(showOnboarding: false),
      ),
    );

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// Drift query streams schedule a zero-duration cleanup timer when their
  /// provider is disposed; unmounting inside the test body and pumping once
  /// flushes it so the pending-timer guard stays quiet.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    // Drift's stream cleanup timer is zero-duration but still needs fake
    // time to elapse, not just a frame.
    await tester.pump(const Duration(milliseconds: 10));
  }

  /// Tall portrait surface so the lazy drill grid builds all six tiles.
  void sizeViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('home renders empty state and the single ball-green CTA',
      (tester) async {
    sizeViewport(tester);
    await tester.pumpWidget(_app(db));
    await tester.pumpAndSettle();
    expect(find.text('RALLYCOACH'), findsOneWidget);
    expect(find.text('No sessions yet. The court is waiting.'),
        findsOneWidget);
    expect(find.text('START SESSION'), findsOneWidget);
    expect(find.byType(RcPrimaryButton), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('start session navigates to drill grid with all six tiles',
      (tester) async {
    sizeViewport(tester);
    await tester.pumpWidget(_app(db));
    await tester.pumpAndSettle();
    await tester.tap(find.text('START SESSION'));
    await tester.pumpAndSettle();
    expect(find.byType(SetupScreen), findsOneWidget);
    for (final label in [
      'FULL ANALYSIS', 'FOREHAND', 'BACKHAND', 'SERVE', 'VOLLEY', 'FOOTWORK',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Maya'), findsOneWidget);
    expect(find.text('Coach K'), findsOneWidget);
    expect(find.text('Doc'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('drill tile selection snaps the border state', (tester) async {
    sizeViewport(tester);
    await tester.pumpWidget(_app(db));
    await tester.pumpAndSettle();
    await tester.tap(find.text('START SESSION'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SERVE'));
    await tester.pumpAndSettle();
    final tile = tester.widget<RcSelectTile>(find.ancestor(
        of: find.text('SERVE'), matching: find.byType(RcSelectTile)));
    expect(tile.selected, isTrue);
    await unmount(tester);
  });

  testWidgets('progress tab shows empty chart hint', (tester) async {
    sizeViewport(tester);
    await tester.pumpWidget(_app(db));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Progress'));
    await tester.pumpAndSettle();
    expect(find.text('PROGRESS'), findsOneWidget);
    expect(find.text('SESSIONS'), findsOneWidget);
    await unmount(tester);
  });
}
