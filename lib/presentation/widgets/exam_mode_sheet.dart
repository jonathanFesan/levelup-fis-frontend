// Arquivo: frontend/lib/presentation/widgets/exam_mode_sheet.dart
// Bottom sheet compartilhado pra escolher o modo da Prova ('facil' ou
// 'dificil') antes de abrir ExamScreen. Usado tanto no nó "Prova" do
// mapa (primeira tentativa) quanto no botão "Tentar novamente" da tela
// de estatísticas — mesmo fluxo, dois pontos de entrada.

import 'package:flutter/material.dart';

Future<String?> showExamModeSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Como você quer fazer a prova?',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w800,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 16),
          _ModoTile(
            titulo: 'Fácil',
            descricao: 'Sem restrições — pode usar o celular normalmente.',
            icon: Icons.sentiment_satisfied_alt_rounded,
            onTap: () => Navigator.of(context).pop('facil'),
          ),
          const SizedBox(height: 12),
          _ModoTile(
            titulo: 'Difícil',
            descricao:
                'Tela cheia, exige internet desligada durante a prova, e '
                'avisa se você tentar sair sem terminar.',
            icon: Icons.local_fire_department_rounded,
            onTap: () => Navigator.of(context).pop('dificil'),
          ),
        ],
      ),
    ),
  );
}

class _ModoTile extends StatelessWidget {
  final String titulo;
  final String descricao;
  final IconData icon;
  final VoidCallback onTap;

  const _ModoTile({
    required this.titulo,
    required this.descricao,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black26),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.black87, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      descricao,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.black38),
            ],
          ),
        ),
      ),
    );
  }
}
