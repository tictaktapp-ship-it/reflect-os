import 'dart:math';

/// Pure deterministic calculator engine for Tool Kit V2.
/// No network, no randomness, no side effects. Given the same inputs and
/// tool key, outputs are always identical.
class CalculatorEngine {
  const CalculatorEngine();

  ToolCalculationResult compute({
    required String toolKey,
    required Map<String, dynamic> inputs,
    required int projectionYears,
    required String confidenceScenario,
    String currencyCode = 'GBP',
  }) {
    final adj = _applyConfidence(inputs, confidenceScenario);

    return switch (toolKey) {
      'roi_calculator_v2'            => _roiCalculator(adj, projectionYears),
      'break_even_calculator_v2'     => _breakEvenCalculator(adj, projectionYears),
      'cost_of_inaction_v2'          => _costOfInaction(adj),
      'headcount_runway_v2'          => _headcountRunway(adj),
      'pricing_change_impact_v2'     => _pricingChangeImpact(adj, projectionYears),
      'scenario_builder_v2'          => _scenarioBuilder(adj, projectionYears),
      'sensitivity_analysis_v2'      => _sensitivityAnalysis(adj),
      'risk_matrix_v2'               => _riskMatrix(adj),
      'ab_test_calculator_v2'        => _abTestCalculator(adj),
      'delivery_confidence_v2'       => _deliveryConfidence(adj),
      'base_rate_lookup_v2'          => _baseRateLookup(adj),
      'reference_class_forecast_v2'  => _referenceClassForecast(adj, projectionYears),
      'attrition_risk_v2'            => _attritionRisk(adj, projectionYears),
      'hiring_success_ramp_v2'       => _hiringSuccessRamp(adj),
      'reorg_impact_v2'              => _reorgImpact(adj, projectionYears),
      'stakeholder_alignment_v2'     => _stakeholderAlignment(adj),
      'outcome_metric_builder_v2'    => _outcomeMetricBuilder(adj),
      _                              => ToolCalculationResult.empty(toolKey),
    };
  }

  // ── Confidence pass-through ───────────────────────────────────────────────

  Map<String, dynamic> _applyConfidence(
    Map<String, dynamic> inputs,
    String scenario,
  ) =>
      Map<String, dynamic>.from(inputs);

  double _n(dynamic v) => (v as num?)?.toDouble() ?? 0.0;
  int    _i(dynamic v) => (v as num?)?.toInt() ?? 0;

  // ── Tool 1: ROI Calculator ────────────────────────────────────────────────

  ToolCalculationResult _roiCalculator(Map<String, dynamic> inp, int years) {
    final initialInvestment = _n(inp['initial_investment']);
    final implMonths        = _i(inp['implementation_months']);
    final year1Benefit      = _n(inp['year_1_benefit']);
    final benefitGrowthRate = _n(inp['benefit_growth_rate']) / 100;
    final annualMaintenance = _n(inp['annual_maintenance_cost']);
    final annualSupport     = _n(inp['annual_support_cost']);
    final costGrowthRate    = _n(inp['cost_growth_rate']) / 100;
    final discountRate      = _n(inp['discount_rate']) / 100;
    final taxRate           = _n(inp['tax_rate']) / 100;

    final projections = <Map<String, dynamic>>[];
    double cumulativeNet = -initialInvestment;
    double npv           = -initialInvestment;
    double totalBenefit  = 0;
    double totalCost     = initialInvestment;
    int?   paybackMonth;
    final  cashflows     = <double>[-initialInvestment];

    for (int yr = 1; yr <= years; yr++) {
      final benefitReady    = (yr * 12) > implMonths;
      final rawBenefit      = benefitReady
          ? year1Benefit * pow(1 + benefitGrowthRate, yr - 1)
          : 0.0;
      final afterTaxBenefit = rawBenefit * (1 - taxRate);
      final ongoingCost     = (annualMaintenance + annualSupport) *
          pow(1 + costGrowthRate, yr - 1);
      final netCashflow     = afterTaxBenefit - ongoingCost;
      final discountedCF    = netCashflow / pow(1 + discountRate, yr);

      cumulativeNet += netCashflow;
      npv           += discountedCF;
      totalBenefit  += afterTaxBenefit;
      totalCost     += ongoingCost;
      cashflows.add(netCashflow);

      if (paybackMonth == null && cumulativeNet >= 0) {
        paybackMonth = yr * 12;
      }

      projections.add({
        'year': yr,
        'investment': yr == 1 ? initialInvestment : 0.0,
        'benefit': afterTaxBenefit,
        'ongoing_cost': ongoingCost,
        'net_cashflow': netCashflow,
        'discounted_cashflow': discountedCF,
        'cumulative_net': cumulativeNet,
      });
    }

    final irr        = _calculateIRR(cashflows);
    final roiPercent = totalCost > 0
        ? (totalBenefit - totalCost) / totalCost * 100
        : 0.0;

    return ToolCalculationResult(
      toolKey: 'roi_calculator_v2',
      summaryOutputs: {
        'npv':            npv,
        'irr':            irr,
        'payback_months': paybackMonth ?? -1,
        'total_benefit':  totalBenefit,
        'total_cost':     totalCost,
        'roi_percent':    roiPercent,
      },
      annualProjections: projections,
      narrative: 'At base case, you recover your investment'
          '${paybackMonth != null ? ' at month $paybackMonth' : ' beyond the projection period'}. '
          'Over $years years, NPV is ${_fmtCurrency(npv)} and IRR is ${irr.toStringAsFixed(1)}%.',
      isValid: true,
    );
  }

  // ── Tool 2: Break-Even Calculator ────────────────────────────────────────

  ToolCalculationResult _breakEvenCalculator(
      Map<String, dynamic> inp, int years) {
    final fixedCosts          = _n(inp['fixed_costs']);
    final variableCostPerUnit = _n(inp['variable_cost_per_unit']);
    final pricePerUnit        = _n(inp['price_per_unit']);
    final currentUnits        = _n(inp['current_units_sold']);
    final growthRate          = _n(inp['expected_growth_rate']) / 100;

    if (pricePerUnit <= variableCostPerUnit) {
      return ToolCalculationResult.validationError(
        'break_even_calculator_v2',
        'Price per unit must exceed variable cost per unit.',
      );
    }

    final cm      = pricePerUnit - variableCostPerUnit;
    final cmRatio = cm / pricePerUnit * 100;
    final beUnits = fixedCosts / cm;
    final beRev   = beUnits * pricePerUnit;
    final curPL   = currentUnits * cm - fixedCosts;

    final projections    = <Map<String, dynamic>>[];
    int?  periodsToBreak;

    for (int yr = 1; yr <= years; yr++) {
      final units   = currentUnits * pow(1 + growthRate, yr);
      final revenue = units * pricePerUnit;
      final varCosts = units * variableCostPerUnit;
      final profit  = revenue - varCosts - fixedCosts;
      final cumProfit = projections.isEmpty
          ? profit
          : (_n(projections.last['cumulative_profit']) + profit);

      if (periodsToBreak == null && units >= beUnits) periodsToBreak = yr;

      projections.add({
        'year': yr, 'units': units, 'revenue': revenue,
        'variable_costs': varCosts, 'fixed_costs': fixedCosts,
        'profit_loss': profit, 'cumulative_profit': cumProfit,
      });
    }

    return ToolCalculationResult(
      toolKey: 'break_even_calculator_v2',
      summaryOutputs: {
        'break_even_units':          beUnits,
        'break_even_revenue':        beRev,
        'contribution_margin':       cm,
        'contribution_margin_ratio': cmRatio,
        'current_profit_loss':       curPL,
        'periods_to_breakeven':      periodsToBreak ?? -1,
      },
      annualProjections: projections,
      narrative: 'Break-even at ${beUnits.toStringAsFixed(0)} units '
          '(${_fmtCurrency(beRev)} revenue). '
          'Contribution margin: ${cmRatio.toStringAsFixed(1)}%.',
      isValid: true,
    );
  }

  // ── Tool 3: Cost of Inaction ──────────────────────────────────────────────

  ToolCalculationResult _costOfInaction(Map<String, dynamic> inp) {
    final monthlyCost        = _n(inp['monthly_cost']);
    final costGrowthRate     = _n(inp['cost_growth_rate']) / 100;
    final delayMonths        = _i(inp['delay_months']);
    final probInaction       = _n(inp['probability_of_inaction']) / 100;
    final monthlyOpportunity = _n(inp['monthly_opportunity_value']);
    final solutionCost       = _n(inp['solution_cost']);

    double totalCOI = 0;
    final projections = <Map<String, dynamic>>[];

    for (int m = 1; m <= delayMonths; m++) {
      final mc     = monthlyCost * pow(1 + costGrowthRate, m / 12);
      totalCOI    += mc;
      final cumOpp = monthlyOpportunity * m;
      projections.add({
        'month': m, 'monthly_cost': mc,
        'cumulative_cost': totalCOI,
        'opportunity_cost': monthlyOpportunity,
        'total_impact': totalCOI + cumOpp,
      });
    }

    final expectedCost  = totalCOI * probInaction;
    final totalOpp      = monthlyOpportunity * delayMonths;
    final totalImpact   = totalCOI + totalOpp;
    final ratio         = solutionCost > 0 ? totalImpact / solutionCost : null;

    return ToolCalculationResult(
      toolKey: 'cost_of_inaction_v2',
      summaryOutputs: {
        'total_cost_of_inaction': totalCOI,
        'expected_cost':          expectedCost,
        'monthly_run_rate':       monthlyCost,
        'total_opportunity_cost': totalOpp,
        'total_impact':           totalImpact,
        'act_vs_inaction_ratio':  ratio,
      },
      annualProjections: projections,
      narrative: 'Every month you delay costs ${_fmtCurrency(monthlyCost)}. '
          'Over $delayMonths months, the total cost of inaction is ${_fmtCurrency(totalCOI)}, '
          'probability-adjusted to ${_fmtCurrency(expectedCost)}.',
      isValid: true,
    );
  }

  // ── Tool 4: Headcount & Runway ─────────────────────────────────────────

  ToolCalculationResult _headcountRunway(Map<String, dynamic> inp) {
    final currentCash       = _n(inp['current_cash']);
    final currentBurn       = _n(inp['current_monthly_burn']);
    final monthlyRevenue    = _n(inp['monthly_revenue']);
    final revenueGrowthRate = _n(inp['monthly_revenue_growth_rate']) / 100;
    final headcountChange   = _n(inp['headcount_change']);
    final avgFullyLoaded    = _n(inp['avg_fully_loaded_cost']);
    final hiringTimeline    = _i(inp['hiring_timeline_months']);
    final revenuePerHead    = _n(inp['revenue_per_head_monthly']);
    final revenueRampMonths = _i(inp['revenue_ramp_months']);

    final monthlyHCCost = headcountChange * avgFullyLoaded / 12;
    const months        = 24;
    final projections   = <Map<String, dynamic>>[];
    double cashBase     = currentCash;
    double cashNew      = currentCash;
    int?   currentRunway;
    int?   newRunway;

    for (int m = 1; m <= months; m++) {
      final phasedCost = hiringTimeline > 0
          ? monthlyHCCost * (m < hiringTimeline ? m / hiringTimeline : 1.0)
          : monthlyHCCost;
      final revenueContrib = revenueRampMonths > 0
          ? headcountChange * revenuePerHead *
              (m < revenueRampMonths ? m / revenueRampMonths : 1.0)
          : headcountChange * revenuePerHead;
      final rev          = monthlyRevenue * pow(1 + revenueGrowthRate, m) +
          revenueContrib;
      final newBurn      = currentBurn + phasedCost;
      final netBurn      = newBurn - rev;
      final baseNetBurn  = currentBurn -
          monthlyRevenue * pow(1 + revenueGrowthRate, m);

      cashBase -= baseNetBurn;
      cashNew  -= netBurn;

      if (currentRunway == null && cashBase <= 0) currentRunway = m;
      if (newRunway == null && cashNew <= 0) newRunway = m;

      projections.add({
        'month': m,
        'cash_balance_base': cashBase,
        'cash_balance_new': cashNew,
        'monthly_burn': newBurn,
        'monthly_revenue': rev,
        'net_burn': netBurn,
      });
    }

    currentRunway ??= months + 1;
    newRunway     ??= months + 1;

    return ToolCalculationResult(
      toolKey: 'headcount_runway_v2',
      summaryOutputs: {
        'new_runway_months':     newRunway,
        'runway_change_months':  newRunway - currentRunway,
        'current_runway_months': currentRunway,
        'new_monthly_burn':      currentBurn + monthlyHCCost,
        'annual_cost_impact':    headcountChange * avgFullyLoaded,
        'runway_zero_date':
            newRunway <= months ? 'Month $newRunway' : '>24 months',
      },
      annualProjections: projections,
      narrative:
          'This headcount change of ${headcountChange.toStringAsFixed(0)} '
          'costs ${_fmtCurrency(headcountChange * avgFullyLoaded / 12)}/month. '
          'New runway: $newRunway months.',
      isValid: true,
    );
  }

  // ── Tool 5: Pricing Change Impact ─────────────────────────────────────────

  ToolCalculationResult _pricingChangeImpact(
      Map<String, dynamic> inp, int years) {
    final currentPrice  = _n(inp['current_price']);
    final currentUnits  = _n(inp['current_units']);
    final cogsPerUnit   = _n(inp['current_cogs_per_unit']);
    final newPrice      = _n(inp['new_price']);
    final elasticity    = _n(inp['price_elasticity']);
    final churnImpact   = _n(inp['churn_impact_percent']) / 100;
    final volumeGrowth  = _n(inp['volume_growth_rate']) / 100;

    if (currentPrice == 0) {
      return ToolCalculationResult.validationError(
          'pricing_change_impact_v2', 'Current price must be greater than 0.');
    }

    final priceChangePct  = (newPrice - currentPrice) / currentPrice;
    final volumeChangePct = elasticity * priceChangePct;
    final unitsYr1        = currentUnits * (1 + volumeChangePct) * (1 - churnImpact);
    final currentRevenue  = currentUnits * currentPrice;

    final projections = <Map<String, dynamic>>[];
    for (int yr = 1; yr <= years; yr++) {
      final units       = unitsYr1 * pow(1 + volumeGrowth, yr - 1);
      final revenue     = units * newPrice;
      final cogs        = units * cogsPerUnit;
      final grossProfit = revenue - cogs;
      final currentTraj = currentUnits * pow(1 + volumeGrowth, yr) * currentPrice;
      projections.add({
        'year': yr, 'units': units, 'revenue': revenue,
        'cogs': cogs, 'gross_profit': grossProfit,
        'vs_current': revenue - currentTraj,
      });
    }

    final revenueYr1      = unitsYr1 * newPrice;
    final revenueDelta    = revenueYr1 - currentRevenue;
    final revenueDeltaPct =
        currentRevenue > 0 ? revenueDelta / currentRevenue * 100 : 0.0;

    return ToolCalculationResult(
      toolKey: 'pricing_change_impact_v2',
      summaryOutputs: {
        'revenue_delta_yr1':     revenueDelta,
        'revenue_delta_percent': revenueDeltaPct,
        'new_units_yr1':         unitsYr1,
        'current_revenue':       currentRevenue,
        'new_revenue_yr1':       revenueYr1,
        'gross_margin_delta':
            (newPrice - cogsPerUnit) * unitsYr1 -
                (currentPrice - cogsPerUnit) * currentUnits,
      },
      annualProjections: projections,
      narrative:
          'A ${(priceChangePct * 100).toStringAsFixed(1)}% price change '
          'is projected to ${revenueDelta >= 0 ? 'increase' : 'decrease'} '
          'year-1 revenue by ${_fmtCurrency(revenueDelta.abs())} '
          '(${revenueDeltaPct.abs().toStringAsFixed(1)}%).',
      isValid: true,
    );
  }

  // ── Tool 6: Scenario Builder ──────────────────────────────────────────────

  ToolCalculationResult _scenarioBuilder(Map<String, dynamic> inp, int years) {
    final bestVal   = _n(inp['best_case_value']);
    final bestProb  = _n(inp['best_case_probability']) / 100;
    final bestGr    = _n(inp['best_case_growth_rate']) / 100;
    final expVal    = _n(inp['expected_case_value']);
    final expProb   = _n(inp['expected_case_probability']) / 100;
    final expGr     = _n(inp['expected_case_growth_rate']) / 100;
    final worstVal  = _n(inp['worst_case_value']);
    final worstProb = _n(inp['worst_case_probability']) / 100;
    final worstGr   = _n(inp['worst_case_growth_rate']) / 100;

    final totalProb = bestProb + expProb + worstProb;
    if ((totalProb - 1.0).abs() > 0.01) {
      return ToolCalculationResult.validationError(
        'scenario_builder_v2',
        'Probabilities must sum to 100%. '
        'Currently: ${(totalProb * 100).toStringAsFixed(0)}%.',
      );
    }

    final evYr1      = bestVal * bestProb + expVal * expProb + worstVal * worstProb;
    final projections = <Map<String, dynamic>>[];
    double cumEV     = 0;

    for (int yr = 1; yr <= years; yr++) {
      final best  = bestVal  * pow(1 + bestGr, yr - 1);
      final exp   = expVal   * pow(1 + expGr, yr - 1);
      final worst = worstVal * pow(1 + worstGr, yr - 1);
      final ev    = best * bestProb + exp * expProb + worst * worstProb;
      cumEV      += ev;
      projections.add({
        'year': yr, 'best_case': best, 'expected_case': exp,
        'worst_case': worst, 'probability_weighted_ev': ev,
        'cumulative_ev': cumEV,
      });
    }

    final upside   = bestVal - evYr1;
    final downside = evYr1 - worstVal;

    return ToolCalculationResult(
      toolKey: 'scenario_builder_v2',
      summaryOutputs: {
        'expected_value_yr1':   evYr1,
        'expected_value_total': cumEV,
        'upside':               upside,
        'downside':             downside,
        'upside_downside_ratio': downside.abs() > 0
            ? upside.abs() / downside.abs()
            : null,
      },
      annualProjections: projections,
      narrative:
          'Probability-weighted EV is ${_fmtCurrency(evYr1)} in year 1, '
          'reaching ${_fmtCurrency(cumEV)} cumulatively over $years years.',
      isValid: true,
    );
  }

  // ── Tool 7: Sensitivity Analysis ─────────────────────────────────────────

  ToolCalculationResult _sensitivityAnalysis(Map<String, dynamic> inp) {
    final baseOutcome = _n(inp['base_outcome']);
    final drivers     = (inp['drivers'] as List<dynamic>?) ?? [];

    final results = drivers.map((d) {
      final m        = d as Map<String, dynamic>;
      final swingPct = _n(m['swing_percent']) / 100;
      final swingAmt = baseOutcome * swingPct;
      return <String, dynamic>{
        'label':       m['label'],
        'base_value':  m['base_value'],
        'unit':        m['unit'],
        'swing_percent': m['swing_percent'],
        'impact_high': swingAmt,
        'impact_low':  swingAmt,
        'swing_range': swingAmt * 2,
      };
    }).toList()
      ..sort((a, b) => (_n(b['swing_range']) - _n(a['swing_range'])).toInt());

    final totalSwing = results.fold(0.0, (s, r) => s + _n(r['swing_range']));
    final top3Swing  =
        results.take(3).fold(0.0, (s, r) => s + _n(r['swing_range']));
    final top3Pct =
        totalSwing > 0 ? top3Swing / totalSwing * 100 : 0.0;

    return ToolCalculationResult(
      toolKey: 'sensitivity_analysis_v2',
      summaryOutputs: {
        'top_driver':         results.isNotEmpty ? results.first['label'] : '',
        'top_driver_swing':   results.isNotEmpty ? results.first['swing_range'] : 0,
        'top3_uncertainty_pct': top3Pct,
      },
      annualProjections: results,
      narrative: results.isNotEmpty
          ? 'The top driver is "${results.first['label']}", '
            'which alone could swing the outcome by '
            '${_fmtCurrency(_n(results.first['swing_range']))}. '
            'Top 3 drivers account for ${top3Pct.toStringAsFixed(0)}% of uncertainty.'
          : 'No drivers entered.',
      isValid: true,
    );
  }

  // ── Tool 8: Risk Matrix ───────────────────────────────────────────────────

  ToolCalculationResult _riskMatrix(Map<String, dynamic> inp) {
    final risks = (inp['risks'] as List<dynamic>?) ?? [];

    final scored = risks.map((r) {
      final m           = r as Map<String, dynamic>;
      final likelihood  = _i(m['likelihood']);
      final impact      = _i(m['impact']);
      final score       = likelihood * impact;
      final level       = score >= 20
          ? 'Critical'
          : score >= 15
              ? 'High'
              : score >= 8
                  ? 'Medium'
                  : 'Low';
      return <String, dynamic>{...m, 'risk_score': score, 'risk_level': level};
    }).toList()
      ..sort((a, b) => (_i(b['risk_score']) - _i(a['risk_score'])));

    final criticalCount = scored.where((r) => r['risk_level'] == 'Critical').length;
    final highCount     = scored.where((r) => r['risk_level'] == 'High').length;
    final totalExposure =
        scored.fold(0.0, (s, r) => s + _n(r['estimated_cost']));

    return ToolCalculationResult(
      toolKey: 'risk_matrix_v2',
      summaryOutputs: {
        'critical_count': criticalCount,
        'high_count':     highCount,
        'total_exposure': totalExposure,
        'top_risk': scored.isNotEmpty ? scored.first['label'] : '',
      },
      annualProjections: scored,
      narrative:
          '$criticalCount critical and $highCount high risks identified. '
          'Total quantified exposure: ${_fmtCurrency(totalExposure)}.',
      isValid: true,
    );
  }

  // ── Tool 9: A/B Test Calculator ──────────────────────────────────────────

  ToolCalculationResult _abTestCalculator(Map<String, dynamic> inp) {
    final baseline = _n(inp['baseline_conversion']) / 100;
    final mde      = _n(inp['minimum_detectable_effect']) / 100;
    final power    = _n(inp['statistical_power']);
    final sig      = _n(inp['significance_level']);
    final traffic  = _n(inp['daily_traffic']);
    final value    = _n(inp['value_per_conversion']);
    final cost     = _n(inp['test_cost']);

    final p1 = baseline;
    final p2 = p1 * (1 + mde);
    final pooledP = (p1 + p2) / 2;

    const zAlphaMap = {1: 2.576, 5: 1.96, 10: 1.645};
    const zBetaMap  = {80: 0.842, 85: 1.036, 90: 1.282, 95: 1.645};

    final zAlpha = zAlphaMap[sig.toInt()] ?? 1.96;
    final zBeta  = zBetaMap[power.toInt()] ?? 0.842;

    final numer = pow(
        zAlpha * sqrt(2 * pooledP * (1 - pooledP)) +
            zBeta * sqrt(p1 * (1 - p1) + p2 * (1 - p2)),
        2);
    final denom = pow(p1 - p2, 2);
    final n     = denom > 0 ? (numer / denom).ceil() : 0;

    final days         = traffic > 0 ? (n / traffic).ceil() : null;
    final annualValue  = traffic > 0
        ? traffic * 365 * (p2 - p1) * value
        : null;
    final testRoi = annualValue != null && cost > 0
        ? (annualValue - cost) / cost * 100
        : null;

    return ToolCalculationResult(
      toolKey: 'ab_test_calculator_v2',
      summaryOutputs: {
        'required_sample_per_variant':    n,
        'estimated_days':                 days,
        'target_conversion_rate':         p2 * 100,
        'annual_value_of_improvement':    annualValue,
        'test_roi':                       testRoi,
      },
      annualProjections: () {
        final estDays = days ?? 30;
        final pts = estDays.clamp(5, 30);
        return List<Map<String, dynamic>>.generate(pts, (i) {
          final d = (i + 1) * (estDays / pts);
          final sample = traffic > 0 ? traffic * d : (i + 1) * 100.0;
          final se = sample > 0 ? sqrt(p1 * (1 - p1) / sample) : 0.05;
          return {
            'year': (d).round(),
            'metric': p1 * 100,
            'lower_bound': ((p1 - 1.96 * se) * 100).clamp(0.0, 100.0),
            'upper_bound': ((p1 + 1.96 * se) * 100).clamp(0.0, 100.0),
          };
        });
      }(),
      narrative:
          'To detect a ${(mde * 100).toStringAsFixed(0)}% relative improvement '
          'with ${power.toStringAsFixed(0)}% power, you need $n visitors per variant'
          '${days != null ? ' (~$days days)' : ''}.',
      isValid: true,
    );
  }

  // ── Tool 10: Delivery Confidence ─────────────────────────────────────────

  ToolCalculationResult _deliveryConfidence(Map<String, dynamic> inp) {
    final opt      = _n(inp['optimistic_weeks']);
    final ml       = _n(inp['most_likely_weeks']);
    final pess     = _n(inp['pessimistic_weeks']);
    final target   = _n(inp['target_weeks']);
    final deps     = _i(inp['dependencies_count']);
    final accuracy = _n(inp['past_estimate_accuracy']) / 100;

    final pert   = (opt + 4 * ml + pess) / 6;
    final stdDev = (pess - opt) / 6;
    final buffer = target - pert;
    final p50    = pert;
    final p80    = pert + 0.842 * stdDev;
    final p90    = pert + 1.282 * stdDev;
    final depRisk  = deps * 0.5 * stdDev;
    final accAdj   = (1 - accuracy) * pert * 0.2;
    final adjP90   = p90 + depRisk + accAdj;
    final risk     = buffer < 0 ? 'High' : buffer < stdDev ? 'Medium' : 'Low';

    return ToolCalculationResult(
      toolKey: 'delivery_confidence_v2',
      summaryOutputs: {
        'pert_estimate':  pert,
        'buffer_weeks':   buffer,
        'schedule_risk':  risk,
        'p50_weeks':      p50,
        'p80_weeks':      p80,
        'p90_weeks':      p90,
        'adjusted_p90':   adjP90,
      },
      annualProjections: () {
        final maxWk = adjP90.ceil().clamp(1, 52);
        return List<Map<String, dynamic>>.generate(maxWk, (i) {
          final w = (i + 1).toDouble();
          final z = stdDev > 0 ? (w - pert) / stdDev : (w >= pert ? 6.0 : -6.0);
          // Approximation of Φ(z) — logistic approximation
          final prob = (100.0 / (1.0 + exp(-1.7 * z))).clamp(0.0, 100.0);
          return {
            'year': i + 1,
            'metric': prob,
            'lower_bound': (prob - 8.0).clamp(0.0, 100.0),
            'upper_bound': (prob + 8.0).clamp(0.0, 100.0),
          };
        });
      }(),
      narrative: 'PERT estimate: ${pert.toStringAsFixed(1)} weeks. '
          'Buffer vs target: ${buffer.toStringAsFixed(1)} weeks. '
          'Risk: $risk. P80: ${p80.toStringAsFixed(1)} weeks, '
          'P90: ${p90.toStringAsFixed(1)} weeks.',
      isValid: true,
    );
  }

  // ── Tool 11: Base Rate Lookup ─────────────────────────────────────────────

  ToolCalculationResult _baseRateLookup(Map<String, dynamic> inp) {
    final total       = _n(inp['total_similar_decisions']);
    final successes   = _n(inp['successful_decisions']);
    final insideView  = _n(inp['inside_view_probability']);
    final insideWt    = _n(inp['inside_view_weight']) / 100;

    if (successes > total) {
      return ToolCalculationResult.validationError(
          'base_rate_lookup_v2', 'Successes cannot exceed total cases.');
    }

    final baseRate = total > 0 ? successes / total * 100 : 0.0;
    final blended  = insideView * insideWt + baseRate * (1 - insideWt);
    final gap      = insideView - baseRate;
    final interp   = gap > 20
        ? 'Significantly overconfident'
        : gap > 10
            ? 'Moderately overconfident'
            : gap < -20
                ? 'Significantly underconfident'
                : gap < -10
                    ? 'Moderately underconfident'
                    : 'Well-calibrated';

    return ToolCalculationResult(
      toolKey: 'base_rate_lookup_v2',
      summaryOutputs: {
        'blended_probability':       blended,
        'base_rate':                 baseRate,
        'calibration_gap':           gap,
        'calibration_interpretation': interp,
      },
      annualProjections: [
        {'year': 1, 'label': 'Base Rate',   'metric': baseRate,   'lower_bound': 0.0, 'upper_bound': baseRate},
        {'year': 2, 'label': 'Inside View', 'metric': insideView, 'lower_bound': 0.0, 'upper_bound': insideView},
        {'year': 3, 'label': 'Blended',     'metric': blended,    'lower_bound': 0.0, 'upper_bound': blended},
      ],
      narrative: 'Historical base rate: ${baseRate.toStringAsFixed(1)}%. '
          'Your inside view: ${insideView.toStringAsFixed(1)}% '
          '(gap: ${gap.toStringAsFixed(1)}%). '
          'Blended: ${blended.toStringAsFixed(1)}%. Assessment: $interp.',
      isValid: true,
    );
  }

  // ── Tool 12: Reference Class Forecast ────────────────────────────────────

  ToolCalculationResult _referenceClassForecast(
      Map<String, dynamic> inp, int years) {
    final rcMean   = _n(inp['reference_class_mean']);
    final rcP10    = _n(inp['reference_class_p10']);
    final rcP90    = _n(inp['reference_class_p90']);
    final inside   = _n(inp['inside_view_estimate']);
    final adjPct   = _n(inp['adjustment_percent']) / 100;

    final anchored = rcMean;
    final adjusted = anchored * (1 + adjPct);
    final bias     = rcMean > 0 ? (inside - rcMean) / rcMean * 100 : 0.0;

    final projections = List<Map<String, dynamic>>.generate(years, (i) => {
      'year': i + 1,
      'base_forecast': adjusted,
      'optimistic': rcP90 * (1 + adjPct),
      'pessimistic': rcP10 * (1 + adjPct),
    });

    return ToolCalculationResult(
      toolKey: 'reference_class_forecast_v2',
      summaryOutputs: {
        'adjusted_forecast': adjusted,
        'anchored_forecast': anchored,
        'optimism_bias':     bias,
        'p10_p90_range':     '${_fmtNum(rcP10)} – ${_fmtNum(rcP90)}',
      },
      annualProjections: projections,
      narrative:
          'Your estimate of ${_fmtNum(inside)} is '
          '${bias >= 0 ? '${bias.abs().toStringAsFixed(1)}% above' : '${bias.abs().toStringAsFixed(1)}% below'} '
          'the reference class mean. '
          'Anchored: ${_fmtNum(anchored)}. Adjusted: ${_fmtNum(adjusted)}.',
      isValid: true,
    );
  }

  // ── Tool 13: Attrition Risk ───────────────────────────────────────────────

  ToolCalculationResult _attritionRisk(Map<String, dynamic> inp, int years) {
    final teamSize        = _i(inp['team_size']);
    final avgSalary       = _n(inp['avg_annual_salary']);
    final attritionRate   = _n(inp['attrition_rate_percent']) / 100;
    final replacementMult = _n(inp['replacement_cost_multiplier']);
    final retentionInvest = _n(inp['retention_investment_annual']);
    final attrRedPct      = _n(inp['expected_attrition_reduction_percent']) / 100;

    final leavers       = teamSize * attritionRate;
    final costPerLeaver = avgSalary * replacementMult;
    final annualCost    = leavers * costPerLeaver;
    final adjRate       = attritionRate * (1 - attrRedPct);
    final adjCost       = teamSize * adjRate * costPerLeaver;
    final savingAnnual  = annualCost - adjCost;
    final retRoi        = retentionInvest > 0
        ? (savingAnnual - retentionInvest) / retentionInvest * 100
        : null;

    final projections = List<Map<String, dynamic>>.generate(years, (i) => {
      'year': i + 1,
      'expected_leavers':      leavers,
      'attrition_cost':        annualCost,
      'retention_investment':  retentionInvest,
      'net_cost':              annualCost - retentionInvest,
      'cumulative_net':        (annualCost - retentionInvest) * (i + 1),
    });

    return ToolCalculationResult(
      toolKey: 'attrition_risk_v2',
      summaryOutputs: {
        'total_annual_attrition_cost': annualCost,
        'expected_leavers_annual':     leavers,
        'cost_per_leaver':             costPerLeaver,
        'retention_roi':               retRoi,
        'cumulative_3yr_cost':         annualCost * years,
        'cumulative_3yr_with_retention':
            (adjCost + retentionInvest) * years,
      },
      annualProjections: projections,
      narrative:
          'At ${(attritionRate * 100).toStringAsFixed(0)}% attrition, '
          '${leavers.toStringAsFixed(1)} leavers/year cost '
          '${_fmtCurrency(costPerLeaver)} each = ${_fmtCurrency(annualCost)}/year.',
      isValid: true,
    );
  }

  // ── Tool 14: Hiring Success & Ramp ───────────────────────────────────────

  ToolCalculationResult _hiringSuccessRamp(Map<String, dynamic> inp) {
    final salary        = _n(inp['annual_salary']);
    final timeToHire    = _i(inp['time_to_hire_months']);
    final recruiterFee  = _n(inp['recruiter_fee_percent']) / 100;
    final rampMonths    = _i(inp['ramp_months']);
    final prodAtEnd     = _n(inp['productivity_at_ramp_end']) / 100;
    final mgrTime       = _n(inp['manager_time_percent']) / 100;
    final monthlyValue  = _n(inp['expected_monthly_value']);

    final monthlySalary = salary / 12;
    final fee           = salary * recruiterFee;
    const totalMonths   = 24;
    final projections   = <Map<String, dynamic>>[];
    double cumNet       = -fee;
    int?   breakeven;

    for (int m = 1; m <= totalMonths; m++) {
      final effectiveM = m - timeToHire;
      final prod       = effectiveM <= 0
          ? 0.0
          : effectiveM >= rampMonths
              ? prodAtEnd
              : (effectiveM / rampMonths) * prodAtEnd;
      final value    = monthlyValue * prod;
      final mgrCost  = effectiveM > 0 && effectiveM <= rampMonths
          ? monthlySalary * mgrTime
          : 0.0;
      final netMonth = value - monthlySalary - mgrCost;
      cumNet        += netMonth;

      if (breakeven == null && cumNet >= 0) breakeven = m;

      projections.add({
        'month': m, 'salary_cost': monthlySalary,
        'productivity_pct': prod * 100,
        'value_generated': value, 'net_month': netMonth,
        'cumulative_net': cumNet,
      });
    }

    final prodLoss = projections
        .where((p) => _n(p['productivity_pct']) < 100)
        .fold(0.0, (s, p) => s + (monthlySalary - _n(p['value_generated'])));

    return ToolCalculationResult(
      toolKey: 'hiring_success_ramp_v2',
      summaryOutputs: {
        'total_cost_to_productivity':  prodLoss + fee,
        'months_to_full_productivity': timeToHire + rampMonths,
        'productivity_loss_cost':      prodLoss,
        'recruiter_fee':               fee,
        'roi_breakeven_month':         breakeven ?? -1,
        'net_value_2yr':               cumNet,
      },
      annualProjections: projections,
      narrative:
          'Total cost to full productivity: ${_fmtCurrency(prodLoss + fee)}. '
          'Net positive value from month ${breakeven ?? 'N/A'}. '
          '2-year net value: ${_fmtCurrency(cumNet)}.',
      isValid: true,
    );
  }

  // ── Tool 15: Re-Org Impact ────────────────────────────────────────────────

  ToolCalculationResult _reorgImpact(Map<String, dynamic> inp, int years) {
    final headcount        = _i(inp['affected_headcount']);
    final avgSalary        = _n(inp['avg_annual_salary']);
    final transitionMonths = _i(inp['transition_months']);
    final prodLossPct      = _n(inp['productivity_loss_percent']) / 100;
    final redundancy       = _n(inp['redundancy_cost_per_head']);
    final changeMgmt       = _n(inp['change_management_cost']);
    final recruitment      = _n(inp['recruitment_cost']);
    final efficiencySaving = _n(inp['expected_efficiency_saving_annual']);
    final benefitMonths    = _i(inp['benefit_realisation_months']);

    final monthlySalaryPool = headcount * avgSalary / 12;
    final totalProdLoss     = monthlySalaryPool * prodLossPct * transitionMonths;
    final totalRedundancy   = headcount * redundancy;
    final totalCost         = totalProdLoss + totalRedundancy + changeMgmt + recruitment;

    final totalMonths  = years * 12;
    final projections  = <Map<String, dynamic>>[];
    double cumNet      = -totalCost;
    int?   payback;

    for (int m = 1; m <= totalMonths; m++) {
      final saving = benefitMonths > 0
          ? (efficiencySaving / 12) *
              (m <= benefitMonths ? m / benefitMonths : 1.0)
          : efficiencySaving / 12;
      cumNet += saving;
      if (payback == null && cumNet >= 0) payback = m;
      projections.add({
        'month': m,
        'productivity_cost': m <= transitionMonths
            ? monthlySalaryPool * prodLossPct
            : 0.0,
        'one_time_costs': m == 1
            ? totalRedundancy + changeMgmt + recruitment
            : 0.0,
        'efficiency_saving': saving,
        'net_month': saving -
            (m <= transitionMonths ? monthlySalaryPool * prodLossPct : 0.0),
        'cumulative_net': cumNet,
      });
    }

    return ToolCalculationResult(
      toolKey: 'reorg_impact_v2',
      summaryOutputs: {
        'total_reorg_cost':       totalCost,
        'payback_months':         payback ?? -1,
        'net_2yr_position':       cumNet,
        'total_productivity_loss': totalProdLoss,
        'total_redundancy_cost':   totalRedundancy,
        'annual_saving':           efficiencySaving,
      },
      annualProjections: projections,
      narrative: 'Total restructure cost: ${_fmtCurrency(totalCost)}. '
          'Annual efficiency saving: ${_fmtCurrency(efficiencySaving)}. '
          '${payback != null ? 'Payback at month $payback.' : 'No payback within projection period.'}',
      isValid: true,
    );
  }

  // ── Tool 16: Stakeholder Alignment ───────────────────────────────────────

  ToolCalculationResult _stakeholderAlignment(Map<String, dynamic> inp) {
    final stakeholders = (inp['stakeholders'] as List<dynamic>?) ?? [];

    if (stakeholders.isEmpty) {
      return ToolCalculationResult(
        toolKey: 'stakeholder_alignment_v2',
        summaryOutputs: {'alignment_score': 0.0, 'alignment_level': 'No data'},
        annualProjections: [],
        narrative: 'No stakeholders entered.',
        isValid: true,
      );
    }

    double weightedSum = 0;
    double maxPossible = 0;
    final  scored      = <Map<String, dynamic>>[];

    for (final s in stakeholders) {
      final m         = s as Map<String, dynamic>;
      final influence = _i(m['influence']);
      final support   = _i(m['support']);
      weightedSum    += influence * support;
      maxPossible    += influence * 5;
      scored.add({...m, 'weighted_score': influence * support});
    }

    final score     = maxPossible > 0 ? weightedSum / maxPossible * 100 : 0.0;
    final level     = score >= 80
        ? 'Strong'
        : score >= 60
            ? 'Moderate'
            : score >= 40
                ? 'Weak'
                : 'Critical';
    final champions = scored
        .where((s) => _i(s['influence']) >= 4 && _i(s['support']) >= 4)
        .length;
    final blockers  = scored
        .where((s) => _i(s['influence']) >= 4 && _i(s['support']) <= 2)
        .length;
    final lowSupport = scored.where((s) => _i(s['support']) <= 3).toList();
    final priority  = lowSupport.isEmpty
        ? ''
        : lowSupport.reduce(
            (a, b) => _i(a['influence']) >= _i(b['influence']) ? a : b,
          )['name'] as String? ?? '';

    return ToolCalculationResult(
      toolKey: 'stakeholder_alignment_v2',
      summaryOutputs: {
        'alignment_score':          score,
        'alignment_level':          level,
        'champions_count':          champions,
        'blockers_count':           blockers,
        'top_priority_engagement':  priority,
      },
      annualProjections: scored,
      narrative:
          'Alignment: $level (${score.toStringAsFixed(0)}/100). '
          '$champions champions, $blockers blockers.',
      isValid: true,
    );
  }

  // ── Tool 17: Outcome Metric Builder ──────────────────────────────────────

  ToolCalculationResult _outcomeMetricBuilder(Map<String, dynamic> inp) {
    final metrics = (inp['metrics'] as List<dynamic>?) ?? [];

    double weightedSum = 0;
    double totalWeight = 0;
    final  scored      = <Map<String, dynamic>>[];
    int    onTrack     = 0;

    for (final m in metrics) {
      final metric        = m as Map<String, dynamic>;
      final weight        = _n(metric['weight']);
      final baseline      = _n(metric['baseline_value']);
      final target        = _n(metric['target_value']);
      final actual        = metric['actual_value'] != null
          ? _n(metric['actual_value'])
          : null;
      final lowerIsBetter = (metric['direction'] as String?) == 'Lower is better';

      double? progress;
      if (actual != null && (target - baseline).abs() > 0) {
        progress = lowerIsBetter
            ? (baseline - actual) / (baseline - target) * 100
            : (actual - baseline) / (target - baseline) * 100;
        progress = progress.clamp(0.0, 100.0);
        weightedSum += weight * progress;
        totalWeight += weight;
        if (progress >= 80) onTrack++;
      }

      scored.add({...metric, 'progress': progress});
    }

    final overallScore = totalWeight > 0 ? weightedSum / totalWeight : 0.0;
    final quality      = overallScore >= 80
        ? 'Strong'
        : overallScore >= 60
            ? 'Partial'
            : overallScore >= 40
                ? 'Weak'
                : 'Unrealised';

    final tracked = scored.where((s) => s['progress'] != null).toList();
    final topMetric = tracked.isEmpty
        ? ''
        : tracked
              .reduce((a, b) =>
                  _n(a['progress']) >= _n(b['progress']) ? a : b)['label']
              as String? ??
          '';
    final bottomMetric = tracked.isEmpty
        ? ''
        : tracked
              .reduce((a, b) =>
                  _n(a['progress']) <= _n(b['progress']) ? a : b)['label']
              as String? ??
          '';

    return ToolCalculationResult(
      toolKey: 'outcome_metric_builder_v2',
      summaryOutputs: {
        'overall_score':    overallScore,
        'outcome_quality':  quality,
        'metrics_on_track': onTrack,
        'top_metric':       topMetric,
        'bottom_metric':    bottomMetric,
      },
      annualProjections: scored,
      narrative: 'Overall score: ${overallScore.toStringAsFixed(0)}/100 ($quality). '
          '$onTrack of ${tracked.length} metrics on track.',
      isValid: true,
    );
  }

  // ── IRR (Newton-Raphson) ─────────────────────────────────────────────────

  double _calculateIRR(List<double> cashflows,
      {int maxIter = 1000, double tol = 0.0001}) {
    double rate = 0.1;
    for (int i = 0; i < maxIter; i++) {
      double npv  = 0;
      double dnpv = 0;
      for (int t = 0; t < cashflows.length; t++) {
        final factor = pow(1 + rate, t).toDouble();
        npv  += cashflows[t] / factor;
        dnpv -= t * cashflows[t] / (factor * (1 + rate));
      }
      if (dnpv.abs() < 1e-10) break;
      final next = rate - npv / dnpv;
      if ((next - rate).abs() < tol) return next * 100;
      rate = next;
    }
    return rate * 100;
  }

  // ── Formatting helpers ────────────────────────────────────────────────────

  String _fmtCurrency(double v) {
    if (v.abs() >= 1000000) return '£${(v / 1000000).toStringAsFixed(1)}m';
    if (v.abs() >= 1000)    return '£${(v / 1000).toStringAsFixed(0)}k';
    return '£${v.toStringAsFixed(0)}';
  }

  String _fmtNum(double v) =>
      v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 1);
}

// ── Result type ───────────────────────────────────────────────────────────────

class ToolCalculationResult {
  final String toolKey;
  final Map<String, dynamic> summaryOutputs;
  final List<dynamic> annualProjections;
  final String narrative;
  final bool isValid;
  final String? validationError;

  const ToolCalculationResult({
    required this.toolKey,
    required this.summaryOutputs,
    required this.annualProjections,
    required this.narrative,
    required this.isValid,
    this.validationError,
  });

  factory ToolCalculationResult.empty(String toolKey) => ToolCalculationResult(
        toolKey: toolKey,
        summaryOutputs: {},
        annualProjections: [],
        narrative: '',
        isValid: false,
        validationError: 'Unknown tool: $toolKey',
      );

  factory ToolCalculationResult.validationError(
          String toolKey, String message) =>
      ToolCalculationResult(
        toolKey: toolKey,
        summaryOutputs: {},
        annualProjections: [],
        narrative: '',
        isValid: false,
        validationError: message,
      );
}
