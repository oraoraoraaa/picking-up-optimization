import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:x_amap_base/x_amap_base.dart';

import 'package:pickup_op_flutter/src/pickup_optimizer.dart';
import 'package:pickup_op_flutter/src/result_page.dart';

const _driver = LatLng(31.2454, 121.5086); // Lujiazui
const _passenger = LatLng(31.2304, 121.4737); // People's Square
const _meetingA = LatLng(31.2381, 121.4849);
const _meetingB = LatLng(31.2400, 121.4905);

PickupSuggestion _modeSuggestion({
  required MobilityMode mode,
  required bool recommended,
  required LatLng meetingPoint,
  required String name,
  required double driverEtaMin,
  required double passengerEtaMin,
}) {
  return PickupSuggestion(
    stayPut: false,
    mode: mode,
    recommended: recommended,
    meetingPoint: meetingPoint,
    meetingPointName: name,
    meetingPointAddress: 'Huangpu District, Shanghai',
    driverEtaMin: driverEtaMin,
    passengerEtaMin: passengerEtaMin,
    completionMin:
        driverEtaMin > passengerEtaMin ? driverEtaMin : passengerEtaMin,
    driverSavedMin: 14 - driverEtaMin,
    score: scoreOption(driverEtaMin, passengerEtaMin, mode),
    driverRoutePolyline: [_driver, meetingPoint],
    passengerPathPolyline: [_passenger, meetingPoint],
  );
}

PickupSuggestion _stayPutSuggestion({required bool recommended}) {
  return PickupSuggestion(
    stayPut: true,
    mode: null,
    recommended: recommended,
    meetingPoint: _passenger,
    meetingPointName: "People's Square",
    meetingPointAddress: 'Huangpu District, Shanghai',
    driverEtaMin: 14,
    passengerEtaMin: 0,
    completionMin: 14,
    driverSavedMin: 0,
    score: 14,
    driverRoutePolyline: const [_driver, _passenger],
    passengerPathPolyline: const <LatLng>[],
  );
}

OptimizationResult _fakeResult({bool stayPutWins = false}) {
  return OptimizationResult(
    dataSource: 'fallback',
    baselineDriverEtaMin: 14,
    suggestions: stayPutWins
        ? [
            _stayPutSuggestion(recommended: true),
            _modeSuggestion(
              mode: MobilityMode.walking,
              recommended: false,
              meetingPoint: _meetingA,
              name: 'Nanjing East Rd',
              driverEtaMin: 13,
              passengerEtaMin: 6,
            ),
          ]
        : [
            _modeSuggestion(
              mode: MobilityMode.walking,
              recommended: true,
              meetingPoint: _meetingA,
              name: 'Nanjing East Rd',
              driverEtaMin: 7,
              passengerEtaMin: 5,
            ),
            _modeSuggestion(
              mode: MobilityMode.bicycle,
              recommended: false,
              meetingPoint: _meetingB,
              name: 'The Bund',
              driverEtaMin: 6,
              passengerEtaMin: 8,
            ),
            _modeSuggestion(
              mode: MobilityMode.transit,
              recommended: false,
              meetingPoint: _meetingB,
              name: 'The Bund',
              driverEtaMin: 6,
              passengerEtaMin: 12,
            ),
            _stayPutSuggestion(recommended: false),
          ],
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

    testWidgets('renders one suggestion per mode plus stay-put', (
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

      expect(find.text('SUGGESTIONS'), findsOneWidget);
      expect(find.text('Walk 5 min'), findsOneWidget);
      expect(find.text('Bicycle 8 min'), findsOneWidget);
      expect(find.text('Transit 12 min'), findsOneWidget);
      expect(find.text('Stay put'), findsOneWidget);
      // Badge on the recommended tile + detail card title.
      expect(find.text('FASTEST'), findsNWidgets(2));
      expect(
        find.text('Passenger: Walk 5 mins to Nanjing East Rd'),
        findsOneWidget,
      );
      expect(find.text('Driver: Save 7 mins driving time'), findsOneWidget);
      expect(find.text('MEETING UP LOCATION:'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
      expect(find.text('Open in Maps'), findsOneWidget);
    });

    testWidgets('tapping a suggestion switches the detail cards', (
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

      await tester.tap(find.text('Transit 12 min'));
      await tester.pumpAndSettle();

      expect(find.text('ALTERNATIVE'), findsOneWidget);
      expect(
        find.text('Passenger: Take transit 12 mins to The Bund'),
        findsOneWidget,
      );
      expect(find.text('Driver: Save 8 mins driving time'), findsOneWidget);

      await tester.tap(find.text('Stay put'));
      await tester.pumpAndSettle();

      expect(find.text('STAY PUT'), findsOneWidget);
      expect(find.text('Passenger: Stay at the pickup point'), findsOneWidget);
      expect(find.text('Driver: Arrive in 14 mins'), findsOneWidget);
    });

    testWidgets('renders a stay-put recommendation first', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ResultPage(
            request: request,
            runOptimization: (_) async => _fakeResult(stayPutWins: true),
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
      expect(find.text('SUGGESTIONS'), findsOneWidget);
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

    test('bestPerMode keeps the first occurrence per mode in rank order', () {
      EvaluatedOption option(MobilityMode mode, double score) {
        return EvaluatedOption(
          routeIndex: 0,
          meetingPoint: _meetingA,
          mode: mode,
          driverEtaMin: score,
          passengerEtaMin: 1,
          score: score,
        );
      }

      final ranked = [
        option(MobilityMode.bicycle, 8),
        option(MobilityMode.walking, 9),
        option(MobilityMode.bicycle, 10),
        option(MobilityMode.transit, 11),
        option(MobilityMode.walking, 12),
      ];
      final winners = bestPerMode(ranked);

      expect(winners.length, 3);
      expect(winners[0].mode, MobilityMode.bicycle);
      expect(winners[0].score, 8);
      expect(winners[1].mode, MobilityMode.walking);
      expect(winners[1].score, 9);
      expect(winners[2].mode, MobilityMode.transit);
      expect(bestPerMode(const []), isEmpty);
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
