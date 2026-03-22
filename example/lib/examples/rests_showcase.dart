// example/lib/examples/rests_showcase.dart
// Showcase de TODAS as pausas em suas posições corretas segundo Behind Bars

import 'package:flutter/material.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

class RestsShowcaseExample extends StatelessWidget {
  const RestsShowcaseExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rests Showcase - Behind Bars Specification'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Container(
        color: Colors.grey[100],
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildInfoCard(),
              const SizedBox(height: 24),
              _buildRestExample(
                'Whole Rest (Semibreve)',
                'Hangs BELOW 4th line - staffPosition = 2',
                _createWholeRestStaff(),
              ),
              const SizedBox(height: 24),
              _buildRestExample(
                'Half Rest (Mínima)',
                'Sits ON 3rd line (center) - staffPosition = 0',
                _createHalfRestStaff(),
              ),
              const SizedBox(height: 24),
              _buildRestExample(
                'Quarter Rest and Smaller',
                'Centered on staff - staffPosition = 0',
                _createQuarterAndSmallerStaff(),
              ),
              const SizedBox(height: 24),
              _buildRestExample(
                'All Rests Together',
                'Visual comparison',
                _createAllRestsStaff(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.deepPurple),
                const SizedBox(width: 8),
                Text(
                  'Behind Bars Specification',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildSpecItem('• Whole rest: hangs BELOW the 4th line (barra superior toca a linha)'),
            _buildSpecItem('• Half rest: sits ON the 3rd line/center (barra inferior toca a linha)'),
            _buildSpecItem('• Quarter rest and smaller: centered on staff'),
            const SizedBox(height: 8),
            Text(
              'Staff lines are counted from BOTTOM to TOP (1, 2, 3, 4, 5)',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14),
      ),
    );
  }

  Widget _buildRestExample(String title, String description, Staff staff) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Center(
                child: MusicScore(
                  staff: staff,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Staff _createWholeRestStaff() {
    final staff = Staff();
    
    final measure = Measure();
    // Whole rest
    measure.add(Rest(duration: const Duration(DurationType.whole)));
    
    staff.add(measure);
    return staff;
  }

  Staff _createHalfRestStaff() {
    final staff = Staff();
    
    final measure = Measure();
    // Two half rests
    measure.add(Rest(duration: const Duration(DurationType.half)));
    measure.add(Rest(duration: const Duration(DurationType.half)));
    
    staff.add(measure);
    return staff;
  }

  Staff _createQuarterAndSmallerStaff() {
    final staff = Staff();
    
    final measure1 = Measure();
    // Quarter rests
    measure1.add(Rest(duration: const Duration(DurationType.quarter)));
    measure1.add(Rest(duration: const Duration(DurationType.quarter)));
    measure1.add(Rest(duration: const Duration(DurationType.quarter)));
    measure1.add(Rest(duration: const Duration(DurationType.quarter)));

    final measure2 = Measure();
    // Eighth rests
    for (int i = 0; i < 8; i++) {
      measure2.add(Rest(duration: const Duration(DurationType.eighth)));
    }

    final measure3 = Measure();
    // Sixteenth rests
    for (int i = 0; i < 16; i++) {
      measure3.add(Rest(duration: const Duration(DurationType.sixteenth)));
    }

    staff.add(measure1);
    staff.add(measure2);
    staff.add(measure3);
    return staff;
  }

  Staff _createAllRestsStaff() {
    final staff = Staff();
    
    final measure1 = Measure();
    // Whole rest (ocupa o compasso todo)
    measure1.add(Rest(duration: const Duration(DurationType.whole)));

    final measure2 = Measure();
    // Half, quarter, eighth, eighth
    measure2.add(Rest(duration: const Duration(DurationType.half)));
    measure2.add(Rest(duration: const Duration(DurationType.quarter)));
    measure2.add(Rest(duration: const Duration(DurationType.eighth)));
    measure2.add(Rest(duration: const Duration(DurationType.eighth)));

    final measure3 = Measure();
    // Mix: quarter, eighth, sixteenth×2, eighth
    measure3.add(Rest(duration: const Duration(DurationType.quarter)));
    measure3.add(Rest(duration: const Duration(DurationType.eighth)));
    measure3.add(Rest(duration: const Duration(DurationType.sixteenth)));
    measure3.add(Rest(duration: const Duration(DurationType.sixteenth)));
    measure3.add(Rest(duration: const Duration(DurationType.eighth)));
    measure3.add(Rest(duration: const Duration(DurationType.quarter)));

    staff.add(measure1);
    staff.add(measure2);
    staff.add(measure3);
    return staff;
  }
}
