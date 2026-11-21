import 'package:flutter_test/flutter_test.dart';
import 'package:smartattend_flutter/app/app.dart';

void main() {
  testWidgets('renders the SmartAttend auth gate', (tester) async {
    await tester.pumpWidget(const SmartAttendApp());
    await tester.pump(const Duration(seconds: 31));

    final reachedGate = find.text('SmartAttend').evaluate().isNotEmpty ||
        find.text('Welcome back').evaluate().isNotEmpty ||
        find.text('Unable to verify your session').evaluate().isNotEmpty;
    expect(reachedGate, isTrue);
    expect(tester.takeException(), isNull);
  });
}
