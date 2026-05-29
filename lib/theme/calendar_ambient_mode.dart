import 'package:flutter/material.dart';

/// Animated home backdrop behind the calendar (inspired by Bars ambient modes).
enum CalendarAmbientMode {
  aquatic,
  auroraDrift,
  rainVeil,
  snowfall,
  starfield,
  emberBloom,
  bokehMist,
  scanBands,
  prismShards,
  pixelDrift,
  sunsetGlow,
  neonPulse,
  deepLagoon,
  forestMist,
  cosmicDust,
  lavaFlow,
  northernLights,
  silkWaves,
  gyroBlocks,
  meshAurora,
  cherryBlossom,
  crystalHaze,
  sandstorm,
  electricVeil,
  midnightBloom;

  static const CalendarAmbientMode defaultHome = CalendarAmbientMode.aquatic;

  String get label => switch (this) {
        CalendarAmbientMode.aquatic => 'Aquatic',
        CalendarAmbientMode.auroraDrift => 'Aurora drift',
        CalendarAmbientMode.rainVeil => 'Rain veil',
        CalendarAmbientMode.snowfall => 'Snowfall',
        CalendarAmbientMode.starfield => 'Starfield',
        CalendarAmbientMode.emberBloom => 'Ember bloom',
        CalendarAmbientMode.bokehMist => 'Soft bokeh',
        CalendarAmbientMode.scanBands => 'Scan bands',
        CalendarAmbientMode.prismShards => 'Prism shards',
        CalendarAmbientMode.pixelDrift => 'Pixel drift',
        CalendarAmbientMode.sunsetGlow => 'Sunset glow',
        CalendarAmbientMode.neonPulse => 'Neon pulse',
        CalendarAmbientMode.deepLagoon => 'Deep lagoon',
        CalendarAmbientMode.forestMist => 'Forest mist',
        CalendarAmbientMode.cosmicDust => 'Cosmic dust',
        CalendarAmbientMode.lavaFlow => 'Lava flow',
        CalendarAmbientMode.northernLights => 'Northern lights',
        CalendarAmbientMode.silkWaves => 'Silk waves',
        CalendarAmbientMode.gyroBlocks => 'Gyro blocks',
        CalendarAmbientMode.meshAurora => 'Mesh aurora',
        CalendarAmbientMode.cherryBlossom => 'Cherry blossom',
        CalendarAmbientMode.crystalHaze => 'Crystal haze',
        CalendarAmbientMode.sandstorm => 'Sandstorm',
        CalendarAmbientMode.electricVeil => 'Electric veil',
        CalendarAmbientMode.midnightBloom => 'Midnight bloom',
      };

  bool get usesGyro => this == CalendarAmbientMode.gyroBlocks;

  static CalendarAmbientMode fromStorage(String? raw) {
    if (raw == null || raw.isEmpty) return defaultHome;
    for (final mode in CalendarAmbientMode.values) {
      if (mode.name == raw) return mode;
    }
    return defaultHome;
  }

  AmbientPalette get palette => switch (this) {
        CalendarAmbientMode.aquatic => const AmbientPalette(
            base: Color(0xFF031A2B),
            accent: Color(0xFF22D3EE),
            accent2: Color(0xFF0EA5E9),
            glow: Color(0xFF67E8F9),
          ),
        CalendarAmbientMode.auroraDrift => const AmbientPalette(
            base: Color(0xFF0B1028),
            accent: Color(0xFF8B5CF6),
            accent2: Color(0xFF22D3EE),
            glow: Color(0xFF34D399),
          ),
        CalendarAmbientMode.rainVeil => const AmbientPalette(
            base: Color(0xFF0F1419),
            accent: Color(0xFF64748B),
            accent2: Color(0xFF94A3B8),
            glow: Color(0xFFCBD5E1),
          ),
        CalendarAmbientMode.snowfall => const AmbientPalette(
            base: Color(0xFF1E293B),
            accent: Color(0xFFE2E8F0),
            accent2: Color(0xFFCBD5E1),
            glow: Color(0xFFF8FAFC),
          ),
        CalendarAmbientMode.starfield => const AmbientPalette(
            base: Color(0xFF020617),
            accent: Color(0xFFFDE047),
            accent2: Color(0xFF818CF8),
            glow: Color(0xFFFFFFFF),
          ),
        CalendarAmbientMode.emberBloom => const AmbientPalette(
            base: Color(0xFF21100D),
            accent: Color(0xFFFF8E4A),
            accent2: Color(0xFFFF5C3A),
            glow: Color(0xFFFFC26A),
          ),
        CalendarAmbientMode.bokehMist => const AmbientPalette(
            base: Color(0xFF1A1033),
            accent: Color(0xFFF472B6),
            accent2: Color(0xFFC084FC),
            glow: Color(0xFFE879F9),
          ),
        CalendarAmbientMode.scanBands => const AmbientPalette(
            base: Color(0xFF050C18),
            accent: Color(0xFF38BDF8),
            accent2: Color(0xFF1D4ED8),
            glow: Color(0xFF7DD3FC),
          ),
        CalendarAmbientMode.prismShards => const AmbientPalette(
            base: Color(0xFF0B0220),
            accent: Color(0xFFC084FC),
            accent2: Color(0xFF22D3EE),
            glow: Color(0xFFF472B6),
          ),
        CalendarAmbientMode.pixelDrift => const AmbientPalette(
            base: Color(0xFF111827),
            accent: Color(0xFF66E3FF),
            accent2: Color(0xFF7A8CFF),
            glow: Color(0xFF52FFA8),
          ),
        CalendarAmbientMode.sunsetGlow => const AmbientPalette(
            base: Color(0xFF1F1147),
            accent: Color(0xFFF472B6),
            accent2: Color(0xFFDB2777),
            glow: Color(0xFFA78BFA),
          ),
        CalendarAmbientMode.neonPulse => const AmbientPalette(
            base: Color(0xFF070B14),
            accent: Color(0xFF66E3FF),
            accent2: Color(0xFF52FFA8),
            glow: Color(0xFFFF6B9D),
          ),
        CalendarAmbientMode.deepLagoon => const AmbientPalette(
            base: Color(0xFF031C1A),
            accent: Color(0xFF34D399),
            accent2: Color(0xFF10B981),
            glow: Color(0xFF5EEAD4),
          ),
        CalendarAmbientMode.forestMist => const AmbientPalette(
            base: Color(0xFF0F1A14),
            accent: Color(0xFF84CC16),
            accent2: Color(0xFF22C55E),
            glow: Color(0xFFA3E635),
          ),
        CalendarAmbientMode.cosmicDust => const AmbientPalette(
            base: Color(0xFF12081F),
            accent: Color(0xFFE879F9),
            accent2: Color(0xFF6366F1),
            glow: Color(0xFFF0ABFC),
          ),
        CalendarAmbientMode.lavaFlow => const AmbientPalette(
            base: Color(0xFF1A0505),
            accent: Color(0xFFEF4444),
            accent2: Color(0xFFF97316),
            glow: Color(0xFFFBBF24),
          ),
        CalendarAmbientMode.northernLights => const AmbientPalette(
            base: Color(0xFF04121A),
            accent: Color(0xFF2DD4BF),
            accent2: Color(0xFF818CF8),
            glow: Color(0xFF4ADE80),
          ),
        CalendarAmbientMode.silkWaves => const AmbientPalette(
            base: Color(0xFF1A1528),
            accent: Color(0xFFA78BFA),
            accent2: Color(0xFFF9A8D4),
            glow: Color(0xFF93C5FD),
          ),
        CalendarAmbientMode.gyroBlocks => const AmbientPalette(
            base: Color(0xFF0D1117),
            accent: Color(0xFF4FC3F7),
            accent2: Color(0xFFFF8A65),
            glow: Color(0xFFCE93D8),
          ),
        CalendarAmbientMode.meshAurora => const AmbientPalette(
            base: Color(0xFF0A0F1E),
            accent: Color(0xFF7C3AED),
            accent2: Color(0xFF06B6D4),
            glow: Color(0xFFEC4899),
          ),
        CalendarAmbientMode.cherryBlossom => const AmbientPalette(
            base: Color(0xFF1A0A12),
            accent: Color(0xFFF9A8D4),
            accent2: Color(0xFFF472B6),
            glow: Color(0xFFFDF2F8),
          ),
        CalendarAmbientMode.crystalHaze => const AmbientPalette(
            base: Color(0xFF0C1222),
            accent: Color(0xFF93C5FD),
            accent2: Color(0xFFC4B5FD),
            glow: Color(0xFFE0F2FE),
          ),
        CalendarAmbientMode.sandstorm => const AmbientPalette(
            base: Color(0xFF1C1408),
            accent: Color(0xFFFBBF24),
            accent2: Color(0xFFF59E0B),
            glow: Color(0xFFFDE68A),
          ),
        CalendarAmbientMode.electricVeil => const AmbientPalette(
            base: Color(0xFF050814),
            accent: Color(0xFF38BDF8),
            accent2: Color(0xFFA78BFA),
            glow: Color(0xFF22D3EE),
          ),
        CalendarAmbientMode.midnightBloom => const AmbientPalette(
            base: Color(0xFF0A0618),
            accent: Color(0xFF6366F1),
            accent2: Color(0xFFEC4899),
            glow: Color(0xFF818CF8),
          ),
      };
}

class AmbientPalette {
  const AmbientPalette({
    required this.base,
    required this.accent,
    required this.accent2,
    required this.glow,
  });

  final Color base;
  final Color accent;
  final Color accent2;
  final Color glow;
}
