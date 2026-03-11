import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'package:reflect_os/features/risk/data/models/risk_assessment.dart';

class RiskRepository {
  const RiskRepository();

  Future<RiskAssessment?> getLatestRiskAssessment(String decisionId) async {
    final rows = await supabase
        .from('risk_assessments')
        .select()
        .eq('decision_id', decisionId)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    return RiskAssessment.fromJson(rows.first);
  }

  /// Invokes the assess-risk Edge Function via a direct HTTP POST so the
  /// Authorization header is always present (required by verify_jwt: true).
  /// Uses a 30-second timeout to accommodate Anthropic latency.
  Future<void> generateRiskAssessment(String decisionId) async {
    final token =
        Supabase.instance.client.auth.currentSession?.accessToken ?? '';
    final url = '$supabaseProjectUrl/functions/v1/assess-risk';
    final response = await http
        .post(
          Uri.parse(url),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'decision_id': decisionId}),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode >= 400) {
      throw Exception(
          'assess-risk failed (${response.statusCode}): ${response.body}');
    }
  }
}
