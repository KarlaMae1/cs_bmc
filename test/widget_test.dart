// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cs_mobile_app/main.dart';
import 'package:cs_mobile_app/widgets.dart';

void main() {
  testWidgets('shows the login screen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await store.init();

    await tester.pumpWidget(const CsApp());
    await tester.pumpAndSettle();

    expect(find.text('Community Service'), findsOneWidget);
    expect(find.text('Log in to continue'), findsOneWidget);
    expect(find.textContaining('admin@school.edu'), findsOneWidget);
    expect(
      find.textContaining('Use the password set during admin setup.'),
      findsOneWidget,
    );
  });

  testWidgets('profile avatar uses the saved profile photo URL', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ProfileAvatar(
          name: 'Karla',
          photoUrl: 'http://localhost/cs_bmc_api/uploads/profiles/photo.jpg',
        ),
      ),
    );

    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(avatar.foregroundImage, isA<NetworkImage>());
    expect(
      (avatar.foregroundImage! as NetworkImage).url,
      'http://localhost/cs_bmc_api/uploads/profiles/photo.jpg',
    );
  });
}
