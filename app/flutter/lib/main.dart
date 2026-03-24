import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

void main() {
  runApp(const PickupOptimizationApp());
}

typedef RecommendationsFetcher = Future<RecommendationSet> Function();

class PickupOptimizationApp extends StatelessWidget {
  const PickupOptimizationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Picking-Up Optimization',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0E6BA8)),
      ),
      home: const VerticalSlicePage(),
    );
  }
}

class VerticalSlicePage extends StatefulWidget {
  const VerticalSlicePage({super.key, this.fetcher = _runRustAnalyzer});

  final RecommendationsFetcher fetcher;

  @override
  State<VerticalSlicePage> createState() => _VerticalSlicePageState();
}

class _VerticalSlicePageState extends State<VerticalSlicePage> {
  Future<RecommendationSet>? _resultFuture;

  @override
  void initState() {
    super.initState();
    _resultFuture = widget.fetcher();
  }

  Future<void> _reload() async {
    setState(() {
      _resultFuture = widget.fetcher();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Picking-Up Optimization V1 Vertical Slice'),
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
            tooltip: 'Recompute recommendations',
          ),
        ],
      ),
      body: FutureBuilder<RecommendationSet>(
        future: _resultFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Failed to fetch recommendations:\n${snapshot.error}',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            );
          }

          final data = snapshot.data!;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Data source: ${data.dataSource} | Generated: ${data.generatedAt}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Passenger start: ${data.passengerStart.name} (${data.passengerStart.lat.toStringAsFixed(4)}, ${data.passengerStart.lon.toStringAsFixed(4)})',
                ),
                Text(
                  'Driver start: ${data.driverStart.name} (${data.driverStart.lat.toStringAsFixed(4)}, ${data.driverStart.lon.toStringAsFixed(4)})',
                ),
                const SizedBox(height: 16),
                Text(
                  'If passenger stays in place',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Driver ETA: ${data.stayPutOption.driverEtaMin.toStringAsFixed(2)} min',
                        ),
                        Text(
                          'Passenger ETA: ${data.stayPutOption.passengerEtaMin.toStringAsFixed(2)} min',
                        ),
                        Text(
                          'Total ETA: ${data.stayPutOption.totalEtaMin.toStringAsFixed(2)} min',
                        ),
                        const SizedBox(height: 6),
                        Text(data.stayPutOption.rationale),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Top 3 pickup options',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: data.options.length,
                    itemBuilder: (context, index) {
                      final option = data.options[index];
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '#${option.rank} ${option.pickupPoint}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 6),
                              Text('Mode: ${option.mode}'),
                              Text(
                                'Driver ETA: ${option.driverEtaMin.toStringAsFixed(2)} min',
                              ),
                              Text(
                                'Passenger ETA: ${option.passengerEtaMin.toStringAsFixed(2)} min',
                              ),
                              Text(
                                'Total ETA: ${option.totalEtaMin.toStringAsFixed(2)} min',
                              ),
                              Text(
                                'Pickup coordinate: ${option.pickupLat.toStringAsFixed(4)}, ${option.pickupLon.toStringAsFixed(4)}',
                              ),
                              const SizedBox(height: 6),
                              Text(option.rationale),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

Future<RecommendationSet> _runRustAnalyzer() async {
  // use env.PWD first, and use cwd as a fallback
  const rustCoreRelativeDirectory = '../../core';
  final pwd = Platform.environment['PWD'];
  final baseDirectory = (pwd != null && pwd.isNotEmpty)
      ? pwd
      : Directory.current.path;
  final rustCoreDirectory = Directory.fromUri(
    Directory(baseDirectory).uri.resolve('$rustCoreRelativeDirectory/'),
  ).path;

  final result = await Process.run(
    'cargo',
    ['run', '--quiet'],
    workingDirectory: rustCoreDirectory,
    runInShell: true,
    environment: {...Platform.environment},
  );

  if (result.exitCode != 0) {
    throw Exception(
      'Rust analyzer failed (exit ${result.exitCode}): ${result.stderr}',
    );
  }

  final jsonMap = jsonDecode(result.stdout as String) as Map<String, dynamic>;
  return RecommendationSet.fromJson(jsonMap);
}

class RecommendationSet {
  RecommendationSet({
    required this.generatedAt,
    required this.dataSource,
    required this.passengerStart,
    required this.driverStart,
    required this.stayPutOption,
    required this.options,
  });

  final String generatedAt;
  final String dataSource;
  final ScenarioPoint passengerStart;
  final ScenarioPoint driverStart;
  final StayPutOption stayPutOption;
  final List<RecommendationOption> options;

  factory RecommendationSet.fromJson(Map<String, dynamic> json) {
    return RecommendationSet(
      generatedAt: json['generated_at'] as String,
      dataSource: json['data_source'] as String,
      passengerStart: ScenarioPoint.fromJson(
        json['passenger_start'] as Map<String, dynamic>,
      ),
      driverStart: ScenarioPoint.fromJson(
        json['driver_start'] as Map<String, dynamic>,
      ),
      stayPutOption: StayPutOption.fromJson(
        json['stay_put_option'] as Map<String, dynamic>,
      ),
      options: (json['options'] as List<dynamic>)
          .map(
            (option) =>
                RecommendationOption.fromJson(option as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class StayPutOption {
  StayPutOption({
    required this.driverEtaMin,
    required this.passengerEtaMin,
    required this.totalEtaMin,
    required this.rationale,
  });

  final double driverEtaMin;
  final double passengerEtaMin;
  final double totalEtaMin;
  final String rationale;

  factory StayPutOption.fromJson(Map<String, dynamic> json) {
    return StayPutOption(
      driverEtaMin: (json['driver_eta_min'] as num).toDouble(),
      passengerEtaMin: (json['passenger_eta_min'] as num).toDouble(),
      totalEtaMin: (json['total_eta_min'] as num).toDouble(),
      rationale: json['rationale'] as String,
    );
  }
}

class ScenarioPoint {
  ScenarioPoint({required this.name, required this.lon, required this.lat});

  final String name;
  final double lon;
  final double lat;

  factory ScenarioPoint.fromJson(Map<String, dynamic> json) {
    return ScenarioPoint(
      name: json['name'] as String,
      lon: (json['lon'] as num).toDouble(),
      lat: (json['lat'] as num).toDouble(),
    );
  }
}

class RecommendationOption {
  RecommendationOption({
    required this.rank,
    required this.pickupPoint,
    required this.mode,
    required this.driverEtaMin,
    required this.passengerEtaMin,
    required this.totalEtaMin,
    required this.rationale,
    required this.pickupLon,
    required this.pickupLat,
  });

  final int rank;
  final String pickupPoint;
  final String mode;
  final double driverEtaMin;
  final double passengerEtaMin;
  final double totalEtaMin;
  final String rationale;
  final double pickupLon;
  final double pickupLat;

  factory RecommendationOption.fromJson(Map<String, dynamic> json) {
    return RecommendationOption(
      rank: json['rank'] as int,
      pickupPoint: json['pickup_point'] as String,
      mode: json['mode'] as String,
      driverEtaMin: (json['driver_eta_min'] as num).toDouble(),
      passengerEtaMin: (json['passenger_eta_min'] as num).toDouble(),
      totalEtaMin: (json['total_eta_min'] as num).toDouble(),
      rationale: json['rationale'] as String,
      pickupLon: (json['pickup_lon'] as num).toDouble(),
      pickupLat: (json['pickup_lat'] as num).toDouble(),
    );
  }
}
