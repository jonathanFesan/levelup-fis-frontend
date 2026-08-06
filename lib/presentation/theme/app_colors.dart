import 'package:flutter/material.dart';

/// Paleta de cores da marca LevelUp Fís, extraída da logo (navy + creme),
/// com tons de apoio para indicar progresso (dourado para ativo/concluído).
///
/// Centralizada aqui para ficar consistente entre todas as telas — antes
/// vivia como uma classe privada dentro de map_screen.dart, mas agora que
/// temos mais telas (Módulo, Tópico) precisa ser compartilhada.
class AppColors {
  AppColors._();

  static const bg = Color(0xFF0E1A40);
  static const card = Color(0xFF1D2948);
  static const cream = Color(0xFFFCF3C8);
  static const gold = Color(0xFFFFC65C);
  static const goldDeep = Color(0xFFFF9D42);
  static const muted = Color(0xFF7C84B8);
  static const lockedFill = Color(0xFF222C58);
  static const divider = Color(0xFF2A3566);

  /// Quase-branco, usado em textos que precisam de contraste maior que o
  /// `cream` padrão (ex: enunciado e alternativas da tela de Exercício).
  static const textoQuaseBranco = Color(0xFFFAFAFC);

  /// Verde de sucesso/acerto — usado na tela de Resultado e em qualquer
  /// feedback positivo futuro.
  static const success = Color(0xFF4CD97B);

  /// Vermelho/rosa de erro — mesma cor já usada nos corações de vida
  /// (chances de erro) na tela de Exercício, agora centralizada aqui.
  static const error = Color(0xFFFF5C7A);
}