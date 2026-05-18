import 'package:flutter/material.dart';

abstract final class AppColors {
  // ── Primary (azules) ────────────────────────────────────────────────────
  static const Color primary900 = Color(0xFF0D47A1);
  static const Color primary700 =
      Color(0xFF1565C0); // marca principal, AppBar, botones
  static const Color primary500 = Color(0xFF1E88E5);
  static const Color primary100 = Color(0xFFBBDEFB);
  static const Color primary50 = Color(0xFFE3F2FD);

  // ── Secondary (verdes) ──────────────────────────────────────────────────
  static const Color secondary700 =
      Color(0xFF2E7D32); // vendedor activo, zonas seguras
  static const Color secondary500 = Color(0xFF43A047);
  static const Color secondary100 = Color(0xFFC8E6C9);
  static const Color secondary50 = Color(0xFFF1F8E9); // fondo Home Vendedor

  // ── Semánticos ──────────────────────────────────────────────────────────
  static const Color danger700 = Color(0xFFC62828); // zonas riesgo Alto
  static const Color danger500 = Color(0xFFE53935);
  static const Color warning700 = Color(0xFFE65100); // zonas riesgo Medio, FAB
  static const Color warning500 = Color(0xFFF57C00);
  static const Color info500 = Color(0xFF0277BD); // zonas riesgo Bajo
  static const Color success500 = Color(0xFF388E3C);

  // ── Neutros ─────────────────────────────────────────────────────────────
  static const Color neutral900 = Color(0xFF212121); // texto principal
  static const Color neutral600 = Color(0xFF616161); // texto secundario
  static const Color neutral400 = Color(0xFF9E9E9E); // texto deshabilitado
  static const Color neutral200 = Color(0xFFE0E0E0); // bordes
  static const Color neutral100 = Color(0xFFF5F5F5); // fondo general
  static const Color neutral0 = Color(0xFFFFFFFF); // superficies, tarjetas

  // ── Aliases semánticos para uso en widgets ──────────────────────────────
  static const Color textPrimary = neutral900;
  static const Color textSecondary = neutral600;
  static const Color textDisabled = neutral400;
  static const Color border = neutral200;
  static const Color background = neutral100;
  static const Color surface = neutral0;

  // ── Mapa ────────────────────────────────────────────────────────────────
  static const Color mapVendorActive = secondary500; // marcador verde
  static const Color mapVendorInactive = neutral400;
  static const Color mapBuyerLocation = primary700; // punto azul pulsante
}
