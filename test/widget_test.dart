import 'package:flutter_test/flutter_test.dart';
import 'package:nhom2_appchamcongnhanvien/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp(isLoggedIn: false));
    expect(find.byType(MyApp), findsOneWidget);
  });
}
