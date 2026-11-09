import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:caku_apps/main.dart';
import 'package:caku_apps/utils/constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('menampilkan layar PIN saat aplikasi memiliki PIN',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      PinUtils.pinKey: PinUtils.hashPin('1234'),
    });

    await tester.pumpWidget(const MyApp(hasPin: true));
    await tester.pumpAndSettle();

    expect(find.text('Masukkan PIN Anda'), findsOneWidget);
    expect(find.text('Caku Finance'), findsOneWidget);
  });

  testWidgets('menampilkan dashboard saat aplikasi tidak memiliki PIN',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MyApp(hasPin: false));
    await tester.pump();

    expect(find.text('CAKU FINANCE'), findsOneWidget);
  });
}
