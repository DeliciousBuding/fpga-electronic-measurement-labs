import 'dart:ui';

const presetColors = [
  // row 1 — basics
  (0xFFEF4444, '红'),
  (0xFFF97316, '橙'),
  (0xFFEAB308, '黄'),
  (0xFF22C55E, '绿'),
  (0xFF06B6D4, '青'),
  (0xFF3B82F6, '蓝'),
  (0xFF8B5CF6, '紫'),
  (0xFFEC4899, '粉'),
  // row 2 — extended
  (0xFFFFFFFF, '白'),
  (0xFFFF6B6B, '暖红'),
  (0xFFFFD93D, '暖黄'),
  (0xFF6BCB77, '暖绿'),
  (0xFFF472B6, '珊瑚'),
  (0xFF2DD4BF, '薄荷'),
  (0xFFA78BFA, '薰衣草'),
  (0xFFFBBF24, '琥珀'),
  // row 3 — moody
  (0xFFFB923C, '橘'),
  (0xFF34D399, '翠'),
  (0xFF38BDF8, '天蓝'),
  (0xFFE879F9, '洋红'),
];

Color fromRGB(int r, int g, int b) => Color.fromARGB(255, r, g, b);
