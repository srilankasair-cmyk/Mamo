import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/store.dart';

void main() {
  testWidgets('App loads with empty store', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await PartyStore.create();
    await tester.pumpWidget(MyApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('Parties'), findsWidgets);
  });
}
