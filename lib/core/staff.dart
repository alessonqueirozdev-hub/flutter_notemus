// lib/core/staff.dart

import 'measure.dart';

/// Representa uma pauta, que contém compassos.
class Staff {
  final List<Measure> measures = [];
  void add(Measure measure) => measures.add(measure);
}
