class AppRanks {
  static const List<String> ranks = [
    'لواء',
    'عميد',
    'عقيد',
    'مقدم',
    'رائد',
    'نقيب',
    'ملازم أول',
    'ملازم',
  ];

  static String sqlRankOrder([String column = 'rank']) => '''
    CASE $column
      WHEN 'لواء' THEN 0
      WHEN 'عميد' THEN 1
      WHEN 'عقيد' THEN 2
      WHEN 'مقدم' THEN 3
      WHEN 'رائد' THEN 4
      WHEN 'نقيب' THEN 5
      WHEN 'ملازم أول' THEN 6
      WHEN 'ملازم' THEN 7
      ELSE 999
    END
  ''';
}
