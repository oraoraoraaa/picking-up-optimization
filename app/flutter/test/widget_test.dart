import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:x_amap_base/x_amap_base.dart';

import 'package:pickup_op_flutter/src/pickup_optimizer.dart';
import 'package:pickup_op_flutter/src/result_page.dart';

const _driver = LatLng(31.2454, 121.5086); // Lujiazui
const _passenger = LatLng(31.2304, 121.4737); // People's Square

OptimizationResult _fakeResult({bool stayPut = false}) {
  const meeting = LatLng(31.2381, 121.4849);
  return OptimizationResult(
    dataSource: 'fallback',
    baselineDriverEtaMin: 14,
    best: PickupRecommendation(
      stayPut: stayPut,
      meetingPoint: stayPut ? _passenger : meeting,
      meetingPointName: stayPut ? "People's Square" : 'Nanjing East Rd',
      meetingPointAddress: 'Huangpu District, Shanghai',
      mode: stayPut ? null : MobilityMode.walking,
      driverEtaMin: stayPut ? 14 : 7,
      passengerEtaMin: stayPut ? 0 : 5,
      completionMin: stayPut ? 14 : 7,
      driverSavedMin: stayPut ? 0 : 7,
    ),
    driverRoutePolyline: [_driver, if (!stayPut) meeting else _passenger],
    passengerPathPolyline:
        stayPut ? const <LatLng>[] : const [_passenger, meeting],
  );
}

void main() {
  group('ResultPage', () {
    const request = OptimizationRequest(
      driver: _driver,
      driverName: 'Lujiazui',
      passenger: _passenger,
      passengerName: "People's Square",
      apiKey: '',
    );

    testWidgets('renders the design cards for a switch recommendation', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ResultPage(
            request: request,
            runOptimization: (_) async => _fakeResult(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('FASTEST'), findsOneWidget);
      expect(find.text('MEETING UP LOCATION:'), findsOneWidget);
      expect(find.text('Nanjing East Rd'), findsOneWidget);
      expect(
        find.text('Passenger: Walk 5 mins to Nanjing East Rd'),
        findsOneWidget,
      );
      expect(find.text('Driver: Save 7 mins driving time'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
      expect(find.text('Open in Maps'), findsOneWidget);
    });

    testWidgets('renders a stay-put recommendation', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ResultPage(
            request: request,
            runOptimization: (_) async => _fakeResult(stayPut: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Passenger: Stay at the pickup point'), findsOneWidget);
      expect(
        find.textContaining('direct route is already fastest'),
        findsOneWidget,
      );
    });

    testWidgets('shows a loading state while optimizing', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ResultPage(
            request: request,
            runOptimization: (_) => Future<OptimizationResult>.delayed(
              const Duration(milliseconds: 200),
              _fakeResult,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Optimizing your pickup...'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('FASTEST'), findsOneWidget);
    });
  });

  group('engine port (mirrors core/src/engine.rs tests)', () {
    test('reachable modes are gated by distance', () {
      expect(reachableModes(500), [MobilityMode.walking, MobilityMode.bicycle]);
      expect(
        reachableModes(2500),
        [MobilityMode.bicycle, MobilityMode.transit],
      );
      expect(reachableModes(6000), [MobilityMode.transit]);
      expect(reachableModes(10000), isEmpty);
    });

    test('scoring penalizes heavier modes', () {
      final walk = scoreOption(10, 5, MobilityMode.walking);
      final bike = scoreOption(10, 5, MobilityMode.bicycle);
      final transit = scoreOption(10, 5, MobilityMode.transit);
      expect(walk, lessThan(bike));
      expect(bike, lessThan(transit));
    });

    test('candidate generation respects reach, spacing, and cap', () {
      const vertices = 60;
      const totalSecs = 1200.0;
      final route = List<RoutePoint>.generate(vertices, (i) {
        final t = i / (vertices - 1);
        return RoutePoint(
          LatLng(
            _driver.latitude + (_passenger.latitude - _driver.latitude) * t,
            _driver.longitude + (_passenger.longitude - _driver.longitude) * t,
          ),
          totalSecs * t,
        );
      });

      final candidates = generateRouteCandidates(route, _passenger);

      expect(candidates, isNotEmpty);
      expect(candidates.length, lessThanOrEqualTo(EngineTuning.maxCandidates));
      for (final candidate in candidates) {
        expect(
          candidate.passengerStraightM,
          greaterThanOrEqualTo(EngineTuning.minPassengerMoveM),
        );
        expect(
          totalSecs - candidate.driverEtaMin * 60,
          greaterThanOrEqualTo(EngineTuning.minDriverSavingSecs),
        );
      }
      for (var i = 0; i + 1 < candidates.length; i++) {
        expect(
          haversineM(candidates[i].point, candidates[i + 1].point),
          greaterThanOrEqualTo(EngineTuning.minCandidateSpacingM),
        );
      }
    });
  });
}
