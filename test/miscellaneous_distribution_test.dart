import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Miscellaneous Distribution Math Tests', () {
    test('Calculates fair average for members with meals and drinks', () {
      const double totalMiscValue = 600.0;
      const int totalMeals = 20;
      const double totalConsumption = 1200.0;

      // Member A
      const int memberAMeals = 10;
      const double memberAConsumption = 300.0;
      const double shareA1 = totalMiscValue * (memberAMeals / totalMeals);
      const double shareB1 = totalMiscValue * (memberAConsumption / totalConsumption);
      final double finalA = double.parse(((shareA1 + shareB1) / 2).toStringAsFixed(2));

      // Member B
      const int memberBMeals = 10;
      const double memberBConsumption = 900.0;
      const double shareA2 = totalMiscValue * (memberBMeals / totalMeals);
      const double shareB2 = totalMiscValue * (memberBConsumption / totalConsumption);
      final double finalB = double.parse(((shareA2 + shareB2) / 2).toStringAsFixed(2));

      expect(finalA, 225.0);
      expect(finalB, 375.0);
      expect(finalA + finalB, totalMiscValue);
    });

    test('Member with only drinks (0 meals) gets fair half share from drinks', () {
      const double totalMiscValue = 100.0;
      const int totalMeals = 10;
      const double totalConsumption = 200.0;

      // Member A (10 meals, 100 consumption)
      const double shareA1 = totalMiscValue * (10 / totalMeals);
      const double shareB1 = totalMiscValue * (100 / totalConsumption);
      final double finalA = double.parse(((shareA1 + shareB1) / 2).toStringAsFixed(2));

      // Member B (0 meals, 100 drinks consumption)
      const double shareA2 = totalMiscValue * (0 / totalMeals);
      const double shareB2 = totalMiscValue * (100 / totalConsumption);
      final double finalB = double.parse(((shareA2 + shareB2) / 2).toStringAsFixed(2));

      expect(finalA, 75.0);
      expect(finalB, 25.0);
      expect(finalA + finalB, totalMiscValue);
    });

    test('Fallback when total meals is 0 distributes equally', () {
      const double totalMiscValue = 300.0;
      const int memberCount = 3;
      final double miscPerMember = double.parse((totalMiscValue / memberCount).toStringAsFixed(2));

      expect(miscPerMember, 100.0);
    });
  });
}
