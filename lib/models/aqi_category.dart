import 'package:flutter/material.dart';

enum AqiMood { happy, meh, sad, angry, dead }

class AqiCategory {
  final String key;
  final String label;
  final int min;
  final int max;
  final int sampleAqi; // representative value used in preview dots
  final Color bgColor;
  final Color bgDeepColor;
  final AqiMood mood;
  final bool wearsMask;
  final bool isHot;
  final bool coughs;

  const AqiCategory({
    required this.key,
    required this.label,
    required this.min,
    required this.max,
    required this.sampleAqi,
    required this.bgColor,
    required this.bgDeepColor,
    required this.mood,
    required this.wearsMask,
    required this.isHot,
    required this.coughs,
  });
}

const AqiCategory kGood = AqiCategory(
  key: 'GOOD',
  label: 'Good',
  min: 0,
  max: 50,
  sampleAqi: 38,
  bgColor: Color(0xFF46C07A),
  bgDeepColor: Color(0xFF2F9D5E),
  mood: AqiMood.happy,
  wearsMask: false,
  isHot: true,
  coughs: false,
);

const AqiCategory kSatisfactory = AqiCategory(
  key: 'SATISFACTORY',
  label: 'Satisfactory',
  min: 51,
  max: 100,
  sampleAqi: 82,
  bgColor: Color(0xFFB9C64A),
  bgDeepColor: Color(0xFF94A233),
  mood: AqiMood.happy,
  wearsMask: false,
  isHot: true,
  coughs: false,
);

const AqiCategory kModerate = AqiCategory(
  key: 'MODERATE',
  label: 'Moderate',
  min: 101,
  max: 200,
  sampleAqi: 164,
  bgColor: Color(0xFFE8C23A),
  bgDeepColor: Color(0xFFC69F24),
  mood: AqiMood.meh,
  wearsMask: true,
  isHot: true,
  coughs: false,
);

const AqiCategory kPoor = AqiCategory(
  key: 'POOR',
  label: 'Poor',
  min: 201,
  max: 300,
  sampleAqi: 268,
  bgColor: Color(0xFFE8923A),
  bgDeepColor: Color(0xFFC66526),
  mood: AqiMood.sad,
  wearsMask: true,
  isHot: false,
  coughs: true,
);

const AqiCategory kVeryPoor = AqiCategory(
  key: 'VERY_POOR',
  label: 'Very Poor',
  min: 301,
  max: 400,
  sampleAqi: 342,
  bgColor: Color(0xFFD65A32),
  bgDeepColor: Color(0xFFA83F20),
  mood: AqiMood.angry,
  wearsMask: true,
  isHot: false,
  coughs: true,
);

const AqiCategory kSevere = AqiCategory(
  key: 'SEVERE',
  label: 'Severe',
  min: 401,
  max: 500,
  sampleAqi: 437,
  bgColor: Color(0xFFA23350),
  bgDeepColor: Color(0xFF7A2440),
  mood: AqiMood.dead,
  wearsMask: true,
  isHot: false,
  coughs: true,
);

const List<AqiCategory> kAllCategories = [
  kGood,
  kSatisfactory,
  kModerate,
  kPoor,
  kVeryPoor,
  kSevere,
];

AqiCategory categoryForAqi(int aqi) {
  for (final cat in kAllCategories) {
    if (aqi >= cat.min && aqi <= cat.max) return cat;
  }
  return aqi < 0 ? kGood : kSevere;
}

int pm25ToIndiaAqi(double pm25) {
  final breakpoints = [
    (cLow: 0.0, cHigh: 30.0, iLow: 0, iHigh: 50),
    (cLow: 31.0, cHigh: 60.0, iLow: 51, iHigh: 100),
    (cLow: 61.0, cHigh: 90.0, iLow: 101, iHigh: 200),
    (cLow: 91.0, cHigh: 120.0, iLow: 201, iHigh: 300),
    (cLow: 121.0, cHigh: 250.0, iLow: 301, iHigh: 400),
    (cLow: 251.0, cHigh: 500.0, iLow: 401, iHigh: 500),
  ];

  if (pm25 <= 0) return 0;
  if (pm25 > 500) return 500;

  for (final bp in breakpoints) {
    if (pm25 <= bp.cHigh) {
      final clamped = pm25 < bp.cLow ? bp.cLow : pm25;
      final aqi = ((bp.iHigh - bp.iLow) / (bp.cHigh - bp.cLow)) *
              (clamped - bp.cLow) +
          bp.iLow;
      return aqi.round().clamp(0, 500);
    }
  }
  return 500;
}
