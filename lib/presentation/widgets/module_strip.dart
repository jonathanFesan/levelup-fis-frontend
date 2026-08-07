import 'package:flutter/material.dart';

import '../../domain/models/curriculum.dart';
import '../theme/app_colors.dart';

/// Faixa horizontal com um símbolo por módulo, lado a lado, ligados por
/// uma linha — o "mapa geral" do currículo, acima da trilha de exercícios
/// do tópico atual.
///
/// Hoje só os módulos com pelo menos um tópico navegável (real ou em modo
/// de teste — ver `ModuloInfo.navegavel`) aparecem desbloqueados/clicáveis;
/// os demais aparecem como roadmap, acinzentados.
class ModuleStrip extends StatelessWidget {
  final ValueChanged<ModuloInfo> onModuleTap;

  const ModuleStrip({super.key, required this.onModuleTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 86,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: kCurriculo.length,
        itemBuilder: (context, index) {
          final modulo = kCurriculo[index];
          final isLast = index == kCurriculo.length - 1;
          return Row(
            children: [
              _ModuleBadge(
                modulo: modulo,
                // Sempre repassa o toque, mesmo bloqueado — quem decide
                // o que fazer (rolar até o módulo atual, ou mostrar a
                // mensagem "Quase lá!") é o MapScreen, que sabe qual é
                // o módulo aberto hoje e tem contexto pra exibir diálogo.
                onTap: () => onModuleTap(modulo),
              ),
              if (!isLast)
                Container(
                  width: 28,
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  color: modulo.navegavel
                      ? AppColors.gold.withValues(alpha: 0.6)
                      : AppColors.muted.withValues(alpha: 0.25),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ModuleBadge extends StatelessWidget {
  final ModuloInfo modulo;
  final VoidCallback? onTap;

  const _ModuleBadge({required this.modulo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = modulo.navegavel;
    final iconColor = active ? AppColors.bg : AppColors.muted;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: active
                  ? const LinearGradient(
                      colors: [AppColors.gold, AppColors.goldDeep],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: active ? null : AppColors.lockedFill,
              border: active
                  ? null
                  : Border.all(color: AppColors.card, width: 1.5),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: AppColors.gold.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: modulo.customIconBuilder != null
                  ? modulo.customIconBuilder!(iconColor, 22)
                  : Icon(modulo.icon, color: iconColor, size: 22),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 60,
            child: Text(
              modulo.titulo,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: active ? AppColors.cream : AppColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
