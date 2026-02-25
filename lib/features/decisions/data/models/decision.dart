import 'package:freezed_annotation/freezed_annotation.dart';

part 'decision.freezed.dart';
part 'decision.g.dart';

@freezed
abstract class Decision with _$Decision {
  const factory Decision({
    required String id,
    required String title,
    required String status,
    DateTime? decisionDate,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Decision;

  factory Decision.fromJson(Map<String, dynamic> json) =>
      _$DecisionFromJson(json);
}
