/// Where things sit on the compound map.
library;

/// Keeps a normalized (0..1) map coordinate on the canvas.
///
/// Clamped rather than rejected: a drag that ends past the edge means "as far
/// over as it goes", not "cancel the move". The inset keeps a pin's label from
/// hanging half off-screen, which is what happens at a true 0 or 1.
double clampMapPosition(double value) => value.clamp(0.05, 0.95);
