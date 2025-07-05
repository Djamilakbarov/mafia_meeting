// lib/screens/constants/app_colors.dart

import 'package:flutter/material.dart';

class AppColors {
  // Общие цвета
  static const Color primaryColor =
      Color(0xFF8B0000); // Глубокий красный (акцент для "создать")
  static const Color secondaryButtonColor =
      Color(0xFF4A4A4A); // Темно-серый для "присоединиться"
  static const Color accentColor = Color(
      0xFFDAA520); // Золотой/бронзовый для акцентов (кнопка присоединения, иконки)
  static const Color errorColor = Color(0xFFFF5252); // Цвет ошибок

  // Цвета, зависящие от темы (внутри виджетов будем использовать widget.isDarkMode)
  // Эти геттеры будут использоваться в LobbyScreen для получения правильного цвета
  static Color getCardColor(bool isDarkMode) {
    return isDarkMode
        ? const Color(0xFF3B3B3B)
        : const Color(0xFFFFFFFF); // Темный для темной темы, белый для светлой
  }

  static Color getBorderColor(bool isDarkMode) {
    return isDarkMode
        ? const Color(0xFF505050)
        : const Color(
            0xFFCCCCCC); // Темный для темной темы, светлый для светлой
  }

  static Color getTextColor(bool isDarkMode) {
    return isDarkMode
        ? Colors.white
        : Colors.black87; // Белый для темной темы, темно-серый для светлой
  }

  static Color getSecondaryTextColor(bool isDarkMode) {
    return isDarkMode
        ? const Color(0xFFB0B0B0)
        : Colors.grey[700]!; // Светло-серый для темной, темно-серый для светлой
  }

  static Color getBackgroundColor(bool isDarkMode) {
    return isDarkMode
        ? const Color(0xFF1A1A1A)
        : const Color(
            0xFFF0F0F0); // Очень темный для темной, светло-серый для светлой
  }

  static Color getPrimaryGradientColor(bool isDarkMode) {
    return isDarkMode
        ? const Color(0xFF2C2C2C)
        : const Color(0xFFE0E0E0); // Для градиента
  }

  // Цвет AppBar
  static const Color appBarColor = Color(
      0xFF1A1A1A); // Можно оставить статичным или тоже сделать зависимым от темы
}
