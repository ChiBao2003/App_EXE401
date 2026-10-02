import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class DigitalTwinDashboard extends StatelessWidget {
  final double focusScore;
  final double stressLevel;
  final double breakScore;
  final double efficiency;
  final double burnoutRisk;

  const DigitalTwinDashboard({
    super.key,
    this.focusScore = 82.0,
    this.stressLevel = 40.0,
    this.breakScore = 75.0,
    this.efficiency = 80.0,
    this.burnoutRisk = 25.0,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'Digital Twin Productivity Profile',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: RadarChart(
                RadarChartData(
                  radarShape: RadarShape.polygon,
                  borderData: FlBorderData(show: false),
                  titlePositionPercentageOffset: 0.2,
                  radarBorderData: const BorderSide(color: Colors.blueAccent, width: 2),
                  tickBorderData: const BorderSide(color: Colors.grey, width: 1),
                  gridBorderData: const BorderSide(color: Colors.grey, width: 0.5),
                  getTitle: (index, angle) {
                    switch (index) {
                      case 0:
                        return RadarChartTitle(text: 'Focus\n${focusScore.toInt()}');
                      case 1:
                        return RadarChartTitle(text: 'Stress\n${stressLevel.toInt()}');
                      case 2:
                        return RadarChartTitle(text: 'Break\n${breakScore.toInt()}');
                      case 3:
                        return RadarChartTitle(text: 'Efficiency\n${efficiency.toInt()}');
                      default:
                        return const RadarChartTitle(text: '');
                    }
                  },
                  dataSets: [
                    RadarDataSet(
                      fillColor: Colors.blue.withOpacity(0.3),
                      borderColor: Colors.blue,
                      entryRadius: 3,
                      dataEntries: [
                        RadarEntry(value: focusScore),
                        RadarEntry(value: stressLevel),
                        RadarEntry(value: breakScore),
                        RadarEntry(value: efficiency),
                      ],
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: burnoutRisk / 100,
              backgroundColor: Colors.green.shade100,
              color: burnoutRisk > 60 ? Colors.red : (burnoutRisk > 40 ? Colors.orange : Colors.green),
              minHeight: 8,
            ),
            const SizedBox(height: 6),
            Text(
              'Burnout Risk: ${burnoutRisk.toInt()}% (${burnoutRisk > 60 ? 'HIGH' : 'NORMAL'})',
              style: const TextStyle(fontWeight: FontWeight.w600),
            )
          ],
        ),
      ),
    );
  }
}
