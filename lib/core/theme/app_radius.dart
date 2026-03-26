import 'package:flutter/material.dart';

/// Reflect OS — Border Radius Design Tokens
///
/// Principle: proportional radius scale.
/// Larger elements = larger radius. All values derived from base = 4px.
///
/// Usage:
///   borderRadius: AppRadius.smBR   // small chips, badges, tags
///   borderRadius: AppRadius.mdBR   // inputs, buttons, list tiles
///   borderRadius: AppRadius.lgBR   // cards, panels, sections
///   borderRadius: AppRadius.xlBR   // modals, dialogs, bottom sheets
///   borderRadius: AppRadius.xxlBR  // full-screen panels, large sheets
///   borderRadius: AppRadius.pillBR // pill buttons, FABs, toggle chips
class AppRadius {
  AppRadius._();

  // Base unit
  static const double _base = 4.0;

  // Scale
  static const double none = 0.0;
  static const double xs   = _base * 1; //  4px — tiny indicators, progress bars
  static const double sm   = _base * 2; //  8px — badges, status dots, small chips
  static const double md   = _base * 3; // 12px — input fields, buttons, list tiles
  static const double lg   = _base * 4; // 16px — cards, decision cards, panels
  static const double xl   = _base * 5; // 20px — dialogs, modals, bottom sheets
  static const double xxl  = _base * 6; // 24px — large overlays, full-width sheets
  static const double pill = 999.0;     // fully rounded pill shape

  // Convenience BorderRadius objects
  static BorderRadius get xsBR  => BorderRadius.circular(xs);
  static BorderRadius get smBR  => BorderRadius.circular(sm);
  static BorderRadius get mdBR  => BorderRadius.circular(md);
  static BorderRadius get lgBR  => BorderRadius.circular(lg);
  static BorderRadius get xlBR  => BorderRadius.circular(xl);
  static BorderRadius get xxlBR => BorderRadius.circular(xxl);
  static BorderRadius get pillBR => BorderRadius.circular(pill);

  // Tab-specific: rounded top only (for filing cabinet tabs)
  static BorderRadius topOnly(double radius) => BorderRadius.only(
        topLeft: Radius.circular(radius),
        topRight: Radius.circular(radius),
      );

  // Bottom sheet: rounded top only at xxl
  static BorderRadius get sheetTop => topOnly(xxl);
}
