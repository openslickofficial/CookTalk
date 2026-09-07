// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:cooktalk_mobile/main.dart';

void main() {
  testWidgets('CookTalk Pre-Session renders recipe picker and theme toggle', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const CookTalkMobileApp());

    // Verify CookTalk Pre-Session title is rendered
    expect(find.text('CookTalk Pre-Session'), findsOneWidget);
    expect(find.text('Select Recipe to Cook'), findsOneWidget);
    expect(find.text('Start Cooking Session'), findsOneWidget);
  });
}
