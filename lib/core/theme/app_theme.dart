// Tema globale dell'applicazione WFM Mobile
// Palette: Blu SAP professionale + accenti

import 'package:flutter/material.dart';

// ─── COLORI ───────────────────────────────────────────────────────────────────

class AppColors {
  // Blu SAP principale
  static const Color primary = Color(0xFF1F4788);
  static const Color primaryLight = Color(0xFF2E75B6);
  static const Color primaryDark = Color(0xFF0F2D56);
  static const Color primarySurface = Color(0xFFE8F0F7);

  // Accenti
  static const Color accent = Color(0xFF0070F3);
  static const Color accentGreen = Color(0xFF2E7D32);
  static const Color accentOrange = Color(0xFFE65100);
  static const Color accentRed = Color(0xFFC62828);

  // Neutri
  static const Color backgroundPage = Color(0xFFF4F6F9);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF8FAFB);
  static const Color border = Color(0xFFDDE3EC);
  static const Color borderLight = Color(0xFFEEF2F7);

  // Testi
  static const Color textPrimary = Color(0xFF1A2540);
  static const Color textSecondary = Color(0xFF5A6A85);
  static const Color textHint = Color(0xFFAAB4C8);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Stati OdL
  static const Color statusReceived = Color(0xFF1565C0);   // Ricevuto — blu
  static const Color statusInProgress = Color(0xFFE65100); // In corso — arancione
  static const Color statusDone = Color(0xFF2E7D32);       // Terminato — verde
  static const Color statusSuspended = Color(0xFF7B1FA2);  // Sospeso — viola
  static const Color statusNew = Color(0xFF00838F);        // Nuovo — teal

  // Superfici stati (chiaro)
  static const Color statusReceivedBg = Color(0xFFE3F2FD);
  static const Color statusInProgressBg = Color(0xFFFFF3E0);
  static const Color statusDoneBg = Color(0xFFE8F5E9);
  static const Color statusSuspendedBg = Color(0xFFF3E5F5);
  static const Color statusNewBg = Color(0xFFE0F7FA);
}

// ─── TIPOGRAFIA ───────────────────────────────────────────────────────────────

class AppTextStyles {
  static const String fontFamily = 'Roboto';

  // Titoli
  static const TextStyle displayLarge = TextStyle(
    fontSize: 28, fontWeight: FontWeight.w700,
    color: AppColors.textPrimary, letterSpacing: -0.5,
  );
  static const TextStyle headingLarge = TextStyle(
    fontSize: 22, fontWeight: FontWeight.w700,
    color: AppColors.textPrimary, letterSpacing: -0.3,
  );
  static const TextStyle headingMedium = TextStyle(
    fontSize: 18, fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
  static const TextStyle headingSmall = TextStyle(
    fontSize: 15, fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  // Corpo
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 15, fontWeight: FontWeight.w400,
    color: AppColors.textPrimary, height: 1.5,
  );
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 13, fontWeight: FontWeight.w400,
    color: AppColors.textSecondary, height: 1.4,
  );
  static const TextStyle bodySmall = TextStyle(
    fontSize: 12, fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  // Labels
  static const TextStyle labelLarge = TextStyle(
    fontSize: 13, fontWeight: FontWeight.w600,
    color: AppColors.textPrimary, letterSpacing: 0.1,
  );
  static const TextStyle labelMedium = TextStyle(
    fontSize: 11, fontWeight: FontWeight.w500,
    color: AppColors.textSecondary, letterSpacing: 0.3,
  );
  static const TextStyle labelSmall = TextStyle(
    fontSize: 10, fontWeight: FontWeight.w600,
    color: AppColors.textSecondary, letterSpacing: 0.5,
  );

  // Campi modulo
  static const TextStyle fieldLabel = TextStyle(
    fontSize: 11, fontWeight: FontWeight.w600,
    color: AppColors.textSecondary, letterSpacing: 0.4,
  );
  static const TextStyle fieldValue = TextStyle(
    fontSize: 14, fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );
  static const TextStyle fieldValueReadOnly = TextStyle(
    fontSize: 14, fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );
}

// ─── TEMA MATERIAL ────────────────────────────────────────────────────────────

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    fontFamily: AppTextStyles.fontFamily,

    // Palette colori
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: AppColors.textOnPrimary,
      primaryContainer: AppColors.primarySurface,
      onPrimaryContainer: AppColors.primaryDark,
      secondary: AppColors.primaryLight,
      onSecondary: AppColors.textOnPrimary,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      surfaceContainerHighest: AppColors.surfaceVariant,
      outline: AppColors.border,
      error: AppColors.accentRed,
    ),

    // Dialog (AlertDialog, showDialog, ...) — più larghi e leggibili.
    dialogTheme: DialogThemeData(
      // Riduce il margine esterno → dialog largo fino a ~95% schermo
      // su mobile, max 600px su tablet/desktop.
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      backgroundColor: AppColors.surface,
      elevation: 8,
      titleTextStyle: AppTextStyles.headingMedium,
      contentTextStyle: AppTextStyles.bodyLarge,
    ),

    // AppBar
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.textOnPrimary,
      elevation: 0,
      centerTitle: true,
      toolbarHeight: 60,
      titleTextStyle: TextStyle(
        fontSize: 18, fontWeight: FontWeight.w600,
        color: AppColors.textOnPrimary, letterSpacing: 0.1,
      ),
      iconTheme: IconThemeData(color: AppColors.textOnPrimary, size: 26),
      actionsIconTheme: IconThemeData(color: AppColors.textOnPrimary, size: 26),
    ),

    // IconButton
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        iconSize: 26,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.all(10),
      ),
    ),

    // BottomNavigationBar
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surface,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textHint,
      selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),

    // TabBar (dans AppBar bleue → texte blanc)
    tabBarTheme: const TabBarThemeData(
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white60,
      indicatorColor: Colors.white,
      indicatorSize: TabBarIndicatorSize.tab,
      labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
      dividerColor: Colors.white24,
    ),

    // Campi di input
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.accentRed),
      ),
      labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
      hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
    ),

    // ElevatedButton
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        minimumSize: const Size.fromHeight(56),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.3),
        elevation: 0,
      ),
    ),

    // OutlinedButton
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        minimumSize: const Size.fromHeight(52),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        side: const BorderSide(color: AppColors.primary, width: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.2),
      ),
    ),

    // TextButton
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        minimumSize: const Size(64, 44),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),

    // FilledButton
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),

    // Card
    cardTheme: const CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        side: BorderSide(color: AppColors.border),
      ),
      margin: EdgeInsets.zero,
    ),

    // Divisore
    dividerTheme: const DividerThemeData(
      color: AppColors.borderLight,
      thickness: 1,
      space: 0,
    ),

    // Chip
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.primarySurface,
      labelStyle: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),

    scaffoldBackgroundColor: AppColors.backgroundPage,
  );
}

// ─── HELPER UI ────────────────────────────────────────────────────────────────

/// Restituisce colore + sfondo per uno stato OdL
({Color color, Color background, String label}) getStatusStyle(String stato) {
  switch (stato.toUpperCase()) {
    case 'RICEVUTO':
    case 'ASSEGNATO':
    case 'I0001':
      return (color: AppColors.statusReceived, background: AppColors.statusReceivedBg, label: 'Assegnato');
    case 'IN ESECUZIONE':
    case 'IN CORSO':
    case 'I0002':
      return (color: AppColors.statusInProgress, background: AppColors.statusInProgressBg, label: 'In esecuzione');
    case 'IN PAUSA':
      return (color: AppColors.accentOrange, background: const Color(0xFFFFF3E0), label: 'In pausa');
    case 'CHIUSO':
    case 'TERMINATO':
    case 'I0005':
      return (color: AppColors.statusDone, background: AppColors.statusDoneBg, label: 'Chiuso');
    case 'SOSPESO':
    case 'I0003':
      return (color: AppColors.statusSuspended, background: AppColors.statusSuspendedBg, label: 'Sospeso');
    case 'ANNULLATO':
      return (color: AppColors.accentRed, background: const Color(0xFFFDECEC), label: 'Annullato');
    case 'INVIATO A SAP':
    case 'INVIATO_SAP':
      return (color: const Color(0xFF00897B), background: const Color(0xFFE0F2F1), label: 'Inviato SAP');
    default:
      return (color: AppColors.statusNew, background: AppColors.statusNewBg, label: stato);
  }
}
