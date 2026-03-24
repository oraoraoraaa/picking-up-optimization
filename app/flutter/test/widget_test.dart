import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pickup_op_flutter/main.dart';

void main() {
  testWidgets('Vertical slice shell renders title', (
    WidgetTester tester,
  ) async {
    Future<RecommendationSet> fakeFetcher() async {
      return RecommendationSet(
        generatedAt: '2026-03-24T00:00:00Z',
        dataSource: 'test',
        passengerStart: ScenarioPoint(name: 'P', lon: 121.47, lat: 31.23),
        driverStart: ScenarioPoint(name: 'D', lon: 121.50, lat: 31.24),
        stayPutOption: StayPutOption(
          driverEtaMin: 8,
          passengerEtaMin: 0,
          totalEtaMin: 8,
          rationale: 'Passenger stays in place.',
        ),
        options: [
          RecommendationOption(
            rank: 1,
            pickupPoint: 'Mock Pickup',
            mode: 'walking',
            driverEtaMin: 5,
            passengerEtaMin: 4,
            totalEtaMin: 9,
            rationale: 'Mock rationale',
            pickupLon: 121.48,
            pickupLat: 31.23,
          ),
        ],
      );
    }

    await tester.pumpWidget(
      MaterialApp(home: VerticalSlicePage(fetcher: fakeFetcher)),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Picking-Up Optimization V1 Vertical Slice'),
      findsOneWidget,
    );
    expect(find.text('If passenger stays in place'), findsOneWidget);
    expect(find.text('Top 3 pickup options'), findsOneWidget);
  });
}
