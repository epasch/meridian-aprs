import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:meridian_aprs/theme/theme_controller.dart';
import 'package:meridian_aprs/screens/map_screen.dart';
import 'package:meridian_aprs/services/station_service.dart';
import 'package:meridian_aprs/services/tnc_service.dart';

import 'helpers/fake_transport.dart';

void main() {
  testWidgets('MapScreen renders without throwing', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final themeController = await ThemeController.create();
    final service = StationService(FakeTransport());
    final tncService = TncService(service);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeController>.value(value: themeController),
          ChangeNotifierProvider<TncService>.value(value: tncService),
        ],
        child: MaterialApp(
          home: MapScreen(service: service, tncService: tncService),
        ),
      ),
    );

    // Pump a single frame — enough to verify the widget tree builds without
    // throwing. We do not call pumpAndSettle because MapScreen may leave
    // async timers alive.
    await tester.pump();

    // Verify the screen mounted successfully.
    expect(find.byType(MapScreen), findsOneWidget);
  });
}
