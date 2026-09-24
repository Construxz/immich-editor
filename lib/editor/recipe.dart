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
  (key: 'pop', icon: Icons.flare),
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
  'pop' => l.toolPop,
  'vignette' => l.toolVignette,
  'sharpness' => l.toolSharpness,
  _ => key,
};

/// A filter: a built-in look (3D LUT in the app, `tool/make_luts.py`) and its strength 0 … 1.
typedef Filter = ({String id, double strength});

/// The built-in filters, in toolbar order. The ID names the look in the recipe and never
/// changes meaning; a changed look gets a new ID (warm@2).
const filters = [
  'vivid@1',
  'warm@1',
  'cool@1',
  'film@1',
  'fade@1',
  'bw@1',
  'noir@1',
  'sepia@1',
];

/// Display name of filter [id].
String filterName(AppLocalizations l, String id) => switch (id) {
  'vivid@1' => l.filterVivid,
  'warm@1' => l.filterWarm,
  'cool@1' => l.filterCool,
  'film@1' => l.filterFilm,
  'fade@1' => l.filterFade,
  'bw@1' => l.filterBw,
  'noir@1' => l.filterNoir,
  'sepia@1' => l.filterSepia,
  _ => id,
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
    this.filter,
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

  /// Look over the adjustments; null = none.
  final Filter? filter;

  double value(String key) => adjustments[key] ?? 0;

  bool get isGeometryNeutral =>
      quarterTurns == 0 &&
      !flip &&
      angle == 0 &&
      crop.join(',') == '0.0,0.0,1.0,1.0';

  bool get isNeutral =>
      isGeometryNeutral &&
      adjustments.values.every((v) => v == 0) &&
      (filter?.strength ?? 0) == 0;

  /// With filter [f] (null: none); everything else stays.
  Recipe withFilter(Filter? f) => Recipe(
    adjustments: adjustments,
    quarterTurns: quarterTurns,
    flip: flip,
    angle: angle,
    crop: crop,
    filter: f,
  );

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
    filter: filter,
  );

  /// Reads a recipe as [toJson] writes it; unknown fields are skipped.
  factory Recipe.fromJson(Map<String, dynamic> j) {
    final g = j['geometry'] as Map<String, dynamic>?;
    final f = j['filter'] as Map<String, dynamic>?;
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
      filter: f?['id'] is String
          ? (
              id: f!['id'] as String,
              strength: (f['strength'] as num?)?.toDouble() ?? 1,
            )
          : null,
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
    if (filter case (:final id, :final strength) when strength > 0)
      'filter': {'id': id, 'strength': strength},
  };
}

/// The adjustments "Optimieren" may set (D-70, D-74).
const optimizedKeys = [
  'blackPoint',
  'whitePoint',
  'brightness',
  'warmth',
  'tint',
  'saturation',
];

/// [recipe] with the [values] of "Optimieren": its adjustments start from 0, not on top;
/// everything else stays.
Recipe withOptimized(Recipe recipe, Map<String, double> values) =>
    recipe.copyWith(
      adjustments: {
        ...recipe.adjustments,
        for (final k in optimizedKeys) k: 0.0,
        ...values,
      },
    );

/// Largest centered crop with aspect [ratio] (width/height) in a
/// [width]×[height] frame; `null` means free (whole frame).
List<double> cropFor(double? ratio, double width, double height) {
  if (ratio == null) return const [0, 0, 1, 1];
  final w = min(1.0, ratio * height / width);
  final h = min(1.0, width / (ratio * height));
  return [(1 - w) / 2, (1 - h) / 2, w, h];
}
