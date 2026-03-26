import 'package:flutter/material.dart';
import 'dart:ui';

void main() {
  runApp(const PickupOptimizationApp());
}

class PickupOptimizationApp extends StatelessWidget {
  const PickupOptimizationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Picking-Up Optimization',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7FB1D6)),
        scaffoldBackgroundColor: const Color(0xFF111827),
      ),
      debugShowCheckedModeBanner: false,
      home: const DashboardPage(),
    );
  }
}

enum UserMode { driver, passenger }

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  UserMode _mode = UserMode.driver;
  bool _modeMenuExpanded = false;

  @override
  Widget build(BuildContext context) {
    final prompt = _mode == UserMode.driver
        ? "Where's your passenger?"
        : "Where's your driver?";

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: _buildMapPlaceholder()),
            Positioned(top: 20, right: 20, child: _buildModeSelector()),
            Positioned(
              left: 14,
              right: 14,
              bottom: 16,
              child: _buildBottomPanel(prompt),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapPlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment(-0.8, -1),
          end: Alignment(0.8, 1),
          colors: [Color(0xFF0A1A2B), Color(0xFF11253A), Color(0xFF0B1728)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -120,
            left: -80,
            child: _ambientBlob(
              size: 260,
              color: const Color(0xFF4ED1C4).withValues(alpha: 0.16),
            ),
          ),
          Positioned(
            right: -110,
            bottom: 90,
            child: _ambientBlob(
              size: 280,
              color: const Color(0xFF77A9DF).withValues(alpha: 0.14),
            ),
          ),
          // Light route-like grid to mimic map texture before real map wiring.
          Positioned.fill(child: CustomPaint(painter: _MapTexturePainter())),
          const Align(
            alignment: Alignment(0.0, 0.05),
            child: Icon(Icons.my_location, color: Color(0xFF6CD4FF), size: 30),
          ),
        ],
      ),
    );
  }

  Widget _ambientBlob({required double size, required Color color}) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0.0)],
            stops: const [0.0, 1.0],
          ),
        ),
      ),
    );
  }

  Widget _buildModeSelector() {
    if (_modeMenuExpanded) {
      return _glassCard(
        width: 228,
        borderRadius: 22,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mode Selection',
              style: TextStyle(
                color: Color(0xFFF4FAFF),
                fontSize: 17,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            _modeOption(UserMode.driver, "I'm the driver"),
            const SizedBox(height: 7),
            _modeOption(UserMode.passenger, "I'm the passenger"),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () => setState(() => _modeMenuExpanded = true),
      child: _glassCard(
        borderRadius: 20,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Text(
          _mode == UserMode.driver ? 'Driver Mode' : 'Passenger Mode',
          style: const TextStyle(
            color: Color(0xFFF4FAFF),
            fontSize: 17,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _modeOption(UserMode value, String text) {
    final selected = _mode == value;
    return InkWell(
      onTap: () {
        setState(() {
          _mode = value;
          _modeMenuExpanded = false;
        });
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(
            0xFF4D6F92,
          ).withValues(alpha: selected ? 0.54 : 0.36),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: selected ? 0.30 : 0.12),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: const TextStyle(color: Color(0xFFF4FAFF), fontSize: 16),
              ),
            ),
            if (selected)
              const Icon(Icons.check, color: Colors.white, size: 20)
            else
              const SizedBox(width: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomPanel(String prompt) {
    return _glassCard(
      borderRadius: 30,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pick up Optimization',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w500,
              color: Color(0xFF06243C),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            prompt,
            style: const TextStyle(fontSize: 20, color: Color(0xFF5C77BE)),
          ),
          const SizedBox(height: 8),
          _searchBar(),
          const SizedBox(height: 7),
          const Text(
            'Starting from a different location?',
            style: TextStyle(fontSize: 20, color: Color(0xFF5C77BE)),
          ),
          const SizedBox(height: 8),
          _searchBar(),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {},
              style: FilledButton.styleFrom(
                backgroundColor: const Color(
                  0xFF5FC99E,
                ).withValues(alpha: 0.94),
                foregroundColor: const Color(0xFFEFFFF8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.24)),
                elevation: 0,
              ),
              child: const Text(
                'Start Route Optimizing',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchBar() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFF58BFB7).withValues(alpha: 0.93),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: const Row(
        children: [
          Icon(Icons.search, color: Color(0xFFE9FFF8), size: 28),
          SizedBox(width: 10),
          Text(
            'Search for a place or address',
            style: TextStyle(color: Color(0xFFE9FFF8), fontSize: 16.5),
          ),
        ],
      ),
    );
  }

  Widget _glassCard({
    required Widget child,
    double borderRadius = 24,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
    double? width,
  }) {
    final radius = BorderRadius.circular(borderRadius);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: width,
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFFB6EDE7).withValues(alpha: 0.72),
                const Color(0xFF83D5D2).withValues(alpha: 0.60),
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.08),
                blurRadius: 6,
                offset: const Offset(0, -1),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _MapTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final major = Paint()
      ..color = const Color(0xFF9AB0C8).withValues(alpha: 0.25)
      ..strokeWidth = 1.2;
    final minor = Paint()
      ..color = const Color(0xFF9AB0C8).withValues(alpha: 0.14)
      ..strokeWidth = 0.8;

    for (double x = 0; x < size.width; x += 64) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), minor);
    }
    for (double y = 0; y < size.height; y += 54) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), minor);
    }

    for (double x = 30; x < size.width; x += 138) {
      canvas.drawLine(Offset(x, 0), Offset(x + 40, size.height), major);
    }
    for (double y = 36; y < size.height; y += 118) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 30), major);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
