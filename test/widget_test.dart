import 'package:flutter_test/flutter_test.dart';
import 'package:baharjaaun/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const BaharJaaunApp());
    expect(find.byType(BaharJaaunApp), findsOneWidget);
  });
}
