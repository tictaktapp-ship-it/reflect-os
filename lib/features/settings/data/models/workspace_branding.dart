import 'package:flutter/foundation.dart';

@immutable
class WorkspaceBranding {
  const WorkspaceBranding({
    required this.workspaceId,
    this.logoFileUrl,
    this.companyName,
    this.companyTagline,
    this.primaryColorHex,
    this.secondaryColorHex,
    required this.createdAt,
    required this.updatedAt,
  });

  final String workspaceId;
  final String? logoFileUrl;
  final String? companyName;
  final String? companyTagline;
  final String? primaryColorHex;
  final String? secondaryColorHex;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory WorkspaceBranding.fromJson(Map<String, dynamic> json) =>
      WorkspaceBranding(
        workspaceId: json['workspace_id'] as String,
        logoFileUrl: json['logo_file_url'] as String?,
        companyName: json['company_name'] as String?,
        companyTagline: json['company_tagline'] as String?,
        primaryColorHex: json['primary_color_hex'] as String?,
        secondaryColorHex: json['secondary_color_hex'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
}
