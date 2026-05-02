import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:untitled1/core/theme/app_colors.dart';

enum AppTheme { light, dark }

class ThemeState {
  final ThemeData themeData;
  final AppTheme themeMode;

  ThemeState(this.themeData, this.themeMode);
}

abstract class ThemeEvent {}

class ToggleTheme extends ThemeEvent {}

class LoadTheme extends ThemeEvent {}

class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  static final _box = Hive.box('settings');

  ThemeBloc() : super(_getInitialTheme()) {
    on<ToggleTheme>((event, emit) {
      final newMode = state.themeMode == AppTheme.light
          ? AppTheme.dark
          : AppTheme.light;
      _box.put('isDarkMode', newMode == AppTheme.dark);
      emit(_getThemeState(newMode));
    });

    on<LoadTheme>((event, emit) {
      final isDark = _box.get('isDarkMode', defaultValue: false);
      emit(_getThemeState(isDark ? AppTheme.dark : AppTheme.light));
    });
  }

  static ThemeState _getInitialTheme() {
    final isDark = Hive.box('settings').get('isDarkMode', defaultValue: false);
    return _getThemeState(isDark ? AppTheme.dark : AppTheme.light);
  }

  static ThemeState _getThemeState(AppTheme mode) {
    final isDark = mode == AppTheme.dark;
    final background = isDark ? AppColors.darkBackground : AppColors.background;
    final surface = isDark ? AppColors.darkSurface : AppColors.surface;
    final surfaceAlt = isDark ? AppColors.darkSurfaceAlt : AppColors.surfaceAlt;
    final stroke = isDark ? AppColors.darkStroke : AppColors.stroke;
    final textPrimary = isDark ? Colors.white : AppColors.textPrimary;
    final textSecondary = isDark
        ? const Color(0xFF9AA3B2)
        : AppColors.textSecondary;

    final colorScheme =
        (isDark ? const ColorScheme.dark() : const ColorScheme.light())
            .copyWith(
              primary: AppColors.primary,
              secondary: AppColors.accent,
              tertiary: isDark
                  ? const Color(0xFF7EA0FF)
                  : AppColors.primaryLight,
              surface: surface,
              surfaceContainer: surfaceAlt,
              surfaceContainerHighest: surfaceAlt,
              error: AppColors.error,
              outline: stroke,
              onPrimary: Colors.white,
              onSecondary: Colors.white,
              onSurface: textPrimary,
              onSurfaceVariant: textSecondary,
              onError: Colors.white,
            );

    final base = ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      colorScheme: colorScheme,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: background,
      splashFactory: InkRipple.splashFactory,
    );

    final baseTextTheme = GoogleFonts.manropeTextTheme(base.textTheme);
    final textTheme = baseTextTheme.copyWith(
      headlineLarge: TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.15,
        color: textPrimary,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.9,
        color: textPrimary,
      ),
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: textPrimary,
      ),
      titleMedium: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: textPrimary,
      ),
      titleSmall: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: textPrimary,
      ),
      bodyLarge: TextStyle(fontSize: 16, height: 1.52, color: textPrimary),
      bodyMedium: TextStyle(fontSize: 14, height: 1.5, color: textSecondary),
      bodySmall: TextStyle(fontSize: 12, height: 1.4, color: textSecondary),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
        color: Colors.white,
      ),
    );

    return ThemeState(
      base.copyWith(
        textTheme: textTheme,
        appBarTheme: AppBarTheme(
          backgroundColor: isDark
              ? AppColors.darkSurface.withValues(alpha: 0.98)
              : surface.withValues(alpha: 0.98),
          foregroundColor: textPrimary,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.black.withValues(alpha: 0.02),
          elevation: 0,
          centerTitle: false,
          titleTextStyle: textTheme.titleLarge,
          iconTheme: IconThemeData(color: textPrimary, size: 22),
        ),
        cardTheme: CardThemeData(
          color: surface,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: stroke.withValues(alpha: 0.55)),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          height: 72,
          backgroundColor: isDark
              ? AppColors.darkSurface.withValues(alpha: 0.98)
              : Colors.white.withValues(alpha: 0.98),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          indicatorColor: AppColors.primary.withValues(alpha: 0.12),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return IconThemeData(
              size: 22,
              color: selected ? AppColors.primary : textSecondary,
            );
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return textTheme.bodySmall!.copyWith(
              fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
              color: selected ? AppColors.primary : textSecondary,
            );
          }),
        ),
        dividerTheme: DividerThemeData(
          color: stroke.withValues(alpha: isDark ? 0.85 : 0.75),
          space: 1,
          thickness: 1,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: isDark ? AppColors.darkSurfaceAlt : surfaceAlt,
          hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.85)),
          labelStyle: TextStyle(
            color: textSecondary,
            fontWeight: FontWeight.w600,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 18,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: stroke),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: stroke),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: AppColors.error),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: AppColors.error, width: 1.6),
          ),
          prefixIconColor: textSecondary,
          suffixIconColor: textSecondary,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            minimumSize: const Size(0, 54),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            textStyle: textTheme.labelLarge,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: textPrimary,
            side: BorderSide(color: stroke),
            minimumSize: const Size(0, 54),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            textStyle: textTheme.titleSmall,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            textStyle: textTheme.titleSmall,
          ),
        ),
        chipTheme: base.chipTheme.copyWith(
          backgroundColor: surfaceAlt,
          selectedColor: AppColors.primary.withValues(alpha: 0.14),
          secondarySelectedColor: AppColors.primary.withValues(alpha: 0.14),
          side: BorderSide(color: stroke.withValues(alpha: 0.8)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          labelStyle: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w600,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: isDark ? AppColors.darkSurface : surface,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: textSecondary,
          elevation: 0,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
        bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: surface,
          surfaceTintColor: Colors.transparent,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: isDark ? AppColors.darkSurfaceAlt : surface,
          contentTextStyle: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      mode,
    );
  }
}
