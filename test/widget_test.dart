// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanexus/app.dart';
import 'package:finanexus/features/accounts/providers/account_summary_providers.dart';

void main() {
  testWidgets('Displays account & portfolio tabs', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          groupedAccountSummariesProvider
              .overrideWithValue(const AsyncValue.data({})),
          portfolioSummariesProvider
              .overrideWithValue(const AsyncValue.data([])),
        ],
        child: const QuantHubApp(),
      ),
    );

  // Pump a few frames to allow async initialization without waiting for animations to settle.
  await tester.pump();

  // 切换到底部“账户”标签页，加载账户与组合页面。
  await tester.tap(find.text('账户').last);
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('账户'), findsWidgets);
    expect(
      find.byWidgetPredicate((widget) => widget is CupertinoSlidingSegmentedControl),
      findsOneWidget,
    );
  });
}
