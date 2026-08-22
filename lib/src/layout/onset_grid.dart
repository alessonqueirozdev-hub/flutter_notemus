// lib/src/layout/onset_grid.dart

/// Resolution of the shared musical-time grid, in subdivisions of a whole note.
///
/// Two events are "simultaneous" when their onsets land on the same grid step.
/// Onsets are accumulated as doubles, so they have to be quantised before they
/// can be compared or used as a map key — floating-point noise must never split
/// one musical instant into two.
///
/// The grid was 1024, i.e. exactly the value of a 1024th note. That is one step
/// too coarse for the model, which goes down to the 2048th: a 2048th advanced
/// the onset by HALF a step and consecutive ones collapsed onto the same key
/// (measured: sixteen distinct 2048th onsets produced nine keys). 8192 resolves
/// every duration `DurationType` can express and leaves a factor of four for the
/// rounding of nested-tuplet ratios such as a third of a fifth.
const double kOnsetGrid = 8192.0;
