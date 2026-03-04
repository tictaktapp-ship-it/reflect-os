import 'package:flutter_test/flutter_test.dart';
import 'package:reflect_os/features/toolkit/engine/calculator_engine.dart';

void main() {
  group('CalculatorEngine', () {
    const engine = CalculatorEngine();

    test('ROI Calculator — basic positive NPV', () {
      final result = engine.compute(
        toolKey: 'roi_calculator_v2',
        inputs: {
          'initial_investment':      100000,
          'implementation_months':   3,
          'year_1_benefit':          50000,
          'benefit_growth_rate':     10,
          'annual_maintenance_cost': 5000,
          'annual_support_cost':     2000,
          'cost_growth_rate':        3,
          'discount_rate':           10,
          'tax_rate':                0,
        },
        projectionYears:    5,
        confidenceScenario: 'base',
      );
      expect(result.isValid, true);
      expect(result.summaryOutputs['npv'], isA<double>());
      expect(result.summaryOutputs['npv'] as double, greaterThan(0));
      expect(result.annualProjections.length, 5);
    });

    test('Break-Even — validates price > variable cost', () {
      final result = engine.compute(
        toolKey: 'break_even_calculator_v2',
        inputs: {
          'fixed_costs':            10000,
          'variable_cost_per_unit': 50,
          'price_per_unit':         30, // invalid: less than variable cost
          'current_units_sold':     0,
          'expected_growth_rate':   10,
        },
        projectionYears:    3,
        confidenceScenario: 'base',
      );
      expect(result.isValid, false);
      expect(result.validationError, isNotNull);
    });

    test('Scenario Builder — validates probabilities sum to 100', () {
      final result = engine.compute(
        toolKey: 'scenario_builder_v2',
        inputs: {
          'best_case_value':           100000,
          'best_case_probability':     40,
          'best_case_growth_rate':     20,
          'expected_case_value':       60000,
          'expected_case_probability': 40,
          'expected_case_growth_rate': 10,
          'worst_case_value':          20000,
          'worst_case_probability':    10, // only sums to 90
          'worst_case_growth_rate':    0,
        },
        projectionYears:    3,
        confidenceScenario: 'base',
      );
      expect(result.isValid, false);
    });

    test('Determinism — same inputs always produce same output', () {
      const inputs = {
        'initial_investment':      200000,
        'implementation_months':   6,
        'year_1_benefit':          80000,
        'benefit_growth_rate':     15,
        'annual_maintenance_cost': 10000,
        'annual_support_cost':     5000,
        'cost_growth_rate':        3,
        'discount_rate':           12,
        'tax_rate':                25,
      };
      final r1 = engine.compute(
        toolKey:            'roi_calculator_v2',
        inputs:             inputs,
        projectionYears:    5,
        confidenceScenario: 'base',
      );
      final r2 = engine.compute(
        toolKey:            'roi_calculator_v2',
        inputs:             inputs,
        projectionYears:    5,
        confidenceScenario: 'base',
      );
      expect(r1.summaryOutputs['npv'], equals(r2.summaryOutputs['npv']));
      expect(r1.summaryOutputs['irr'], equals(r2.summaryOutputs['irr']));
    });
  });
}
