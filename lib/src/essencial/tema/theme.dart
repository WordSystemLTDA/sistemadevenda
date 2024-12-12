import 'package:app/src/essencial/tema/color_schemes.g.dart';
import 'package:flutter/material.dart';

ThemeData get darkTheme => ThemeData(
      useMaterial3: true,
      colorScheme: MaterialTheme.darkScheme(),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: MaterialTheme.darkScheme().primaryContainer,
      ),
      segmentedButtonTheme: _segmentedButtonTheme,
      inputDecorationTheme: _inputDecorationTheme,
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: _inputDecorationTheme,
        textStyle: const TextStyle(fontSize: 16),
      ),
    );

ThemeData get lightTheme => ThemeData(
      useMaterial3: true,
      colorScheme: MaterialTheme.lightScheme(),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: MaterialTheme.lightScheme().primaryContainer,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: MaterialTheme.lightScheme().primary,
        foregroundColor: MaterialTheme.lightScheme().onPrimary,
      ),
      segmentedButtonTheme: _segmentedButtonTheme,
      inputDecorationTheme: _inputDecorationTheme,
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: _inputDecorationTheme,
        textStyle: const TextStyle(fontSize: 16),
      ),
    );

InputDecorationTheme get _inputDecorationTheme => const InputDecorationTheme(
      contentPadding: EdgeInsets.fromLTRB(10.0, 8.0, 10.0, 10.0),
      constraints: BoxConstraints(maxHeight: 40),
      border: OutlineInputBorder(),
    );

SegmentedButtonThemeData get _segmentedButtonTheme => SegmentedButtonThemeData(
      style: ButtonStyle(
        textStyle: WidgetStateProperty.resolveWith<TextStyle?>((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 9,
            );
          }

          return const TextStyle(
            fontSize: 12,
          );
        }),
      ),
    );
