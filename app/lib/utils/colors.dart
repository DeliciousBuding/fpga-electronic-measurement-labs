import 'dart:ui';

const presetColors = [
  (0xFFEF4444, '红'),
  (0xFFF97316, '橙'),
  (0xFFEAB308, '黄'),
  (0xFF22C55E, '绿'),
  (0xFF06B6D4, '青'),
  (0xFF3B82F6, '蓝'),
  (0xFF8B5CF6, '紫'),
  (0xFFEC4899, '粉'),
  (0xFFFFFFFF, '白'),
  (0xFFFF6B6B, '暖红'),
  (0xFFFFD93D, '暖黄'),
  (0xFF6BCB77, '暖绿'),
];

Color fromRGB(int r, int g, int b) => Color.fromARGB(255, r, g, b);
