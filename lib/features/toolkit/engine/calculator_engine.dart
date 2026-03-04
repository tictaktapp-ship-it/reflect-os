import 'dart:math' as math;

/// Pure deterministic calculator engine — no async, no network, no BuildContext.
///
/// Reads the `type` field from [formulaAst] and dispatches to the matching
/// formula. All formulas accept [inputs] keyed by field id (as returned by
/// the input form) and return a map of output ids → computed values.
class CalculatorEngine {
  const CalculatorEngine();

  /// Computes and returns output values for the given [formulaAst] and [inputs].
  ///
  /// Throws [ArgumentError] for unknown formula types.
  Map<String, dynamic> compute(
    Map<String, dynamic> formulaAst,
    Map<String, dynamic> inputs,
  ) {
    final type = formulaAst['type'] as String? ?? '';
    switch (type) {
      case 'npv':
        return _npv(inputs);
      case 'irr':
        return _irr(inputs);
      case 'payback_period':
        return _paybackPeriod(inputs);
      case 'breakeven_units':
        return _breakevenUnits(inputs);
      case 'weighted_score':
        return _weightedScore(inputs);
      default:
        throw ArgumentError('Unknown formula type: $type');
    }
  }

  // ── NPV ──────────────────────────────────────────────────────────────────

  Map<String, dynamic> _npv(Map<String, dynamic> inputs) {
    final rate =
        (inputs['discount_rate'] as num).toDouble() / 100.0;
    final cashFlows = _toDoubleList(inputs['cash_flows']);
    final initialInvestment =
        (inputs['initial_investment'] as num).toDouble();

    double npv = -initialInvestment;
    for (int t = 0; t < cashFlows.length; t++) {
      npv += cashFlows[t] / math.pow(1 + rate, t + 1);
    }
    return {'npv': _round(npv)};
  }

  // ── IRR (Newton-Raphson) ─────────────────────────────────────────────────

  Map<String, dynamic> _irr(Map<String, dynamic> inputs) {
    final cashFlows = _toDoubleList(inputs['cash_flows']);
    final initialInvestment =
        (inputs['initial_investment'] as num).toDouble();
    final flows = [-initialInvestment, ...cashFlows];

    double r = 0.1; // initial guess: 10 %
    for (int i = 0; i < 100; i++) {
      double npv = 0.0;
      double dnpv = 0.0;
      for (int t = 0; t < flows.length; t++) {
        final factor = math.pow(1 + r, t).toDouble();
        npv += flows[t] / factor;
        if (t > 0) {
          dnpv -= t * flows[t] / (factor * (1 + r));
        }
      }
      if (dnpv.abs() < 1e-12) break;
      final rNext = r - npv / dnpv;
      if ((rNext - r).abs() < 1e-9) {
        r = rNext;
        break;
      }
      r = rNext;
    }
    return {'irr': _round(r * 100.0)}; // return as percentage
  }

  // ── Payback period ───────────────────────────────────────────────────────

  Map<String, dynamic> _paybackPeriod(Map<String, dynamic> inputs) {
    final initialInvestment =
        (inputs['initial_investment'] as num).toDouble();
    final annualCashFlow = (inputs['annual_cash_flow'] as num).toDouble();
    if (annualCashFlow <= 0) return {'payback_period': null};
    return {'payback_period': _round(initialInvestment / annualCashFlow)};
  }

  // ── Breakeven units ──────────────────────────────────────────────────────

  Map<String, dynamic> _breakevenUnits(Map<String, dynamic> inputs) {
    final fixedCosts = (inputs['fixed_costs'] as num).toDouble();
    final pricePerUnit = (inputs['price_per_unit'] as num).toDouble();
    final variableCostPerUnit =
        (inputs['variable_cost_per_unit'] as num).toDouble();
    final contributionMargin = pricePerUnit - variableCostPerUnit;
    if (contributionMargin <= 0) return {'breakeven_units': null};
    return {
      'breakeven_units': _round(fixedCosts / contributionMargin),
    };
  }

  // ── Weighted score ───────────────────────────────────────────────────────

  Map<String, dynamic> _weightedScore(Map<String, dynamic> inputs) {
    final criteria = inputs['criteria'] as List<dynamic>;
    double totalScore = 0.0;
    double totalWeight = 0.0;
    for (final item in criteria) {
      final m = item as Map<String, dynamic>;
      final weight = (m['weight'] as num).toDouble();
      final score = (m['score'] as num).toDouble();
      totalScore += weight * score;
      totalWeight += weight;
    }
    if (totalWeight == 0) return {'weighted_score': 0.0};
    return {'weighted_score': _round(totalScore / totalWeight)};
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  static double _round(double v) => (v * 100).round() / 100.0;

  static List<double> _toDoubleList(dynamic raw) {
    return (raw as List<dynamic>).map((e) => (e as num).toDouble()).toList();
  }
}
