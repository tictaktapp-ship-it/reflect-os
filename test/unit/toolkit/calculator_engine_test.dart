import 'package:flutter_test/flutter_test.dart';
import 'package:reflect_os/features/toolkit/engine/calculator_engine.dart';

void main() {
  const engine = CalculatorEngine();

  group('CalculatorEngine', () {
    group('NPV', () {
      test('positive NPV for profitable cash flows', () {
        // 500/1.1 + 500/1.21 + 500/1.331 = 454.55 + 413.22 + 375.66 = 1243.43
        // NPV = 1243.43 - 1000 = 243.43 > 0
        final result = engine.compute(
          {'type': 'npv'},
          {
            'discount_rate': 10.0,
            'initial_investment': 1000.0,
            'cash_flows': [500.0, 500.0, 500.0],
          },
        );
        final npv = result['npv'] as double;
        expect(npv, greaterThan(0));
        expect(npv, closeTo(243.43, 0.1));
      });

      test('negative NPV when rate is high', () {
        final result = engine.compute(
          {'type': 'npv'},
          {
            'discount_rate': 50.0,
            'initial_investment': 1000.0,
            'cash_flows': [400.0, 400.0, 400.0],
          },
        );
        final npv = result['npv'] as double;
        expect(npv, lessThan(0));
      });

      test('zero discount rate returns sum minus initial', () {
        final result = engine.compute(
          {'type': 'npv'},
          {
            'discount_rate': 0.0,
            'initial_investment': 1000.0,
            'cash_flows': [500.0, 500.0, 500.0],
          },
        );
        final npv = result['npv'] as double;
        expect(npv, closeTo(500.0, 0.01));
      });
    });

    group('IRR', () {
      test('computes IRR close to expected', () {
        // 100% IRR: invest 1000, get back 2000 in year 1
        final result = engine.compute(
          {'type': 'irr'},
          {
            'initial_investment': 1000.0,
            'cash_flows': [2000.0],
          },
        );
        final irr = result['irr'] as double;
        expect(irr, closeTo(100.0, 0.1));
      });
    });

    group('Payback Period', () {
      test('calculates payback correctly', () {
        final result = engine.compute(
          {'type': 'payback_period'},
          {
            'initial_investment': 1000.0,
            'annual_cash_flow': 250.0,
          },
        );
        expect(result['payback_period'], closeTo(4.0, 0.01));
      });

      test('returns null for non-positive cash flow', () {
        final result = engine.compute(
          {'type': 'payback_period'},
          {
            'initial_investment': 1000.0,
            'annual_cash_flow': 0.0,
          },
        );
        expect(result['payback_period'], isNull);
      });
    });

    group('Breakeven Units', () {
      test('calculates breakeven correctly', () {
        final result = engine.compute(
          {'type': 'breakeven_units'},
          {
            'fixed_costs': 10000.0,
            'price_per_unit': 50.0,
            'variable_cost_per_unit': 30.0,
          },
        );
        expect(result['breakeven_units'], closeTo(500.0, 0.01));
      });

      test('returns null when contribution margin is zero', () {
        final result = engine.compute(
          {'type': 'breakeven_units'},
          {
            'fixed_costs': 10000.0,
            'price_per_unit': 30.0,
            'variable_cost_per_unit': 30.0,
          },
        );
        expect(result['breakeven_units'], isNull);
      });
    });

    group('Weighted Score', () {
      test('computes weighted average correctly', () {
        final result = engine.compute(
          {'type': 'weighted_score'},
          {
            'criteria': [
              {'weight': 3.0, 'score': 8.0},
              {'weight': 2.0, 'score': 6.0},
            ],
          },
        );
        // (3*8 + 2*6) / (3+2) = (24+12)/5 = 36/5 = 7.2
        expect(result['weighted_score'], closeTo(7.2, 0.01));
      });

      test('returns zero when total weight is zero', () {
        final result = engine.compute(
          {'type': 'weighted_score'},
          {
            'criteria': <dynamic>[],
          },
        );
        expect(result['weighted_score'], 0.0);
      });
    });

    test('throws for unknown formula type', () {
      expect(
        () => engine.compute({'type': 'unknown'}, {}),
        throwsArgumentError,
      );
    });
  });
}
