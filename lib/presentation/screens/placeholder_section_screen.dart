import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Placeholder genérico de pré-visualização — usado por seções que ainda
/// não têm nenhum conteúdo/desenho de UI definido (Resumo, Prova final,
/// Treinamento). Existe só pra fechar o fluxo de navegação completo
/// durante testes; não representa um design final dessas telas.
class PlaceholderSectionScreen extends StatelessWidget {
  final String moduloTitulo;
  final String topicoTitulo;
  final String secaoTitulo;
  final IconData icon;

  const PlaceholderSectionScreen({
    super.key,
    required this.moduloTitulo,
    required this.topicoTitulo,
    required this.secaoTitulo,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.cream),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.card,
                  ),
                  child: Icon(icon, color: AppColors.gold, size: 32),
                ),
                const SizedBox(height: 20),
                Text(
                  '$moduloTitulo · $topicoTitulo'.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  secaoTitulo,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.cream,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Pré-visualização de navegação — o conteúdo e o design '
                  'desta seção ainda não foram definidos.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
