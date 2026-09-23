import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// An adjustment in "Anpassen": JSON key (as in the renderer), icon; name via [toolName].
typedef Tool = ({String key, IconData icon});

/// The level-1 adjustments, in toolbar order (spec, *Bedienung*).
const tools = <Tool>[
  (key: 'brightness', icon: Icons.brightness_6),
  (key: 'contrast', icon: Icons.contrast),
  (key: 'whitePoint', icon: Icons.circle),
  (key: 'highlights', icon: Icons.wb_sunny),
  (key: 'shadows', icon: Icons.nights_stay),
  (key: 'blackPoint', icon: Icons.circle_outlined),
  (key: 'saturation', icon: Icons.water_drop),
  (key: 'warmth', icon: Icons.thermostat),
  (key: 'tint', icon: Icons.colorize),
  (key: 'blueTones', icon: Icons.water),
  (key: 'vignette', icon: Icons.vignette),
  (key: 'sharpness', icon: Icons.details),
];

/// Display name of the adjustment [key].
String toolName(AppLocalizations l, String key) => switch (key) {
  'brightness' => l.toolBrightness,
  'contrast' => l.toolContrast,
  'whitePoint' => l.toolWhitePoint,
  'highlights' => l.toolHighlights,
  'shadows' => l.toolShadows,
  'blackPoint' => l.toolBlackPoint,
  'saturation' => l.toolSaturation,
  'warmth' => l.toolWarmth,
  'tint' => l.toolTint,
  'blueTones' => l.toolBlueTones,
  'vignette' => l.toolVignette,
  'sharpness' => l.toolSharpness,
  _ => key,
};

/// The settings of an edit. Stored as JSON in the copy's XMP and handed to the
/// native renderer; from the first release on, later versions read older ones.
@immutable
class Recipe {
  const Recipe({
    this.adjustments = const {},
    this.quarterTurns = 0,
    this.flip = false,
    this.angle = 0,
    this.crop = const [0, 0, 1, 1],
  });

  /// Values of the [tools], each −1 … 1; missing = 0 = unchanged.
  final Map<String, double> adjustments;

  /// Clockwise quarter turns, 0 … 3.
  final int quarterTurns;

  /// Flip horizontally, as the rotated image is seen.
  final bool flip;

  /// Straightening in degrees, −45 … 45; the renderer zooms so no corners stay empty.
  final double angle;

  /// x, y, width, height; 0 … 1 in the rotated frame.
  final List<double> crop;

  double value(String key) => adjustments[key] ?? 0;

  bool get isGeometryNeutral =>
      quarterTurns == 0 &&
      !flip &&
      angle == 0 &&
      crop.join(',') == '0.0,0.0,1.0,1.0';

  bool get isNeutral =>
      isGeometryNeutral && adjustments.values.every((v) => v == 0);

  Recipe withValue(String key, double value) =>
      copyWith(adjustments: {...adjustments, key: value});

  Recipe copyWith({
    Map<String, double>? adjustments,
    int? quarterTurns,
    bool? flip,
    double? angle,
    List<double>? crop,
  }) => Recipe(
    adjustments: adjustments ?? this.adjustments,
    quarterTurns: quarterTurns ?? this.quarterTurns,
    flip: flip ?? this.flip,
    angle: angle ?? this.angle,
    crop: crop ?? this.crop,
  );

  /// Reads a recipe as [toJson] writes it; unknown fields are skipped.
  factory Recipe.fromJson(Map<String, dynamic> j) {
    final g = j['geometry'] as Map<String, dynamic>?;
    return Recipe(
      adjustments: {
        for (final t in tools)
          if (j[t.key] is num) t.key: (j[t.key] as num).toDouble(),
      },
      quarterTurns: (g?['quarterTurns'] as num?)?.toInt() ?? 0,
      flip: g?['flip'] == true,
      angle: (g?['angle'] as num?)?.toDouble() ?? 0,
      crop: [
        for (final c in (g?['crop'] as List?) ?? const [0, 0, 1, 1])
          (c as num).toDouble(),
      ],
    );
  }

  /// Equal as a recipe (what would be saved).
  bool sameAs(Recipe o) => jsonEncode(toJson()) == jsonEncode(o.toJson());

  Map<String, Object> toJson() => {
    'v': 1,
    for (final MapEntry(:key, :value) in adjustments.entries)
      if (value != 0) key: value,
    if (!isGeometryNeutral)
      'geometry': {
        'quarterTurns': quarterTurns,
        'flip': flip,
        'angle': angle,
        'crop': crop,
      },
  };
}

/// Largest centered crop with aspect [ratio] (width/height) in a
/// [width]×[height] frame; `null` means free (whole frame).
List<double> cropFor(double? ratio, double width, double height) {
  if (ratio == null) return const [0, 0, 1, 1];
  final w = min(1.0, ratio * height / width);
  final h = min(1.0, width / (ratio * height));
  return [(1 - w) / 2, (1 - h) / 2, w, h];
}
