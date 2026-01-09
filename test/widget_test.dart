// This is a basic Flutter widget test for TXF Leverage App.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:txf_leverage_app/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const TXFLeverageApp());

    // Wait for the app to settle
    await tester.pumpAndSettle();

    // Verify that the app shows the futures type selector
    expect(find.text('大台'), findsOneWidget);
    expect(find.text('小台'), findsOneWidget);
    expect(find.text('微台'), findsOneWidget);
  });
}
