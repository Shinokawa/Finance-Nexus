// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:quant_hub/app.dart';
import 'package:quant_hub/features/accounts/providers/account_summary_providers.dart';

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

    // Wait for first frame to settle.
    await tester.pumpAndSettle();

    expect(find.text('账户与组合'), findsOneWidget);
    expect(find.text('账户列表'), findsOneWidget);
    expect(find.text('组合列表'), findsOneWidget);
  });
}
