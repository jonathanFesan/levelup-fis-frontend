import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../theme/app_colors.dart';

/// Baixa o PDF de [url] pra um arquivo temporário e mostra com
/// flutter_pdfview (zoom por pinça nativo da plataforma, sem nenhum
/// botão de compartilhar/imprimir nosso). Cada instância baixa uma vez
/// só (cache em memória via _futuroArquivo, criado em initState) — abrir
/// e fechar a tela de novo baixa de novo, o que é aceitável pro tamanho
/// normal de um PDF de resumo/curiosidade.
///
/// Extraído de resumo_screen.dart pra ser reaproveitado também em
/// curiosidade_screen.dart — mesmo mecanismo, mais de um lugar usando.
class PdfViewer extends StatefulWidget {
  final String url;

  const PdfViewer({super.key, required this.url});

  @override
  State<PdfViewer> createState() => _PdfViewerState();
}

class _PdfViewerState extends State<PdfViewer> {
  late Future<String> _futuroArquivo;

  @override
  void initState() {
    super.initState();
    _futuroArquivo = _baixarPdf(widget.url);
  }

  @override
  void didUpdateWidget(covariant PdfViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _futuroArquivo = _baixarPdf(widget.url);
    }
  }

  Future<String> _baixarPdf(String url) async {
    final resposta = await http.get(Uri.parse(url));
    if (resposta.statusCode != 200) {
      throw Exception(
        'Não foi possível baixar o PDF (status ${resposta.statusCode}). '
        'Confira se o link está com o compartilhamento público ativado.',
      );
    }
    final pastaTemp = await getTemporaryDirectory();
    // Nome de arquivo baseado no hash da URL, pra não colidir entre
    // tópicos/capítulos diferentes abertos na mesma sessão do app.
    final arquivo = File(
      '${pastaTemp.path}/pdf_${url.hashCode}.pdf',
    );
    await arquivo.writeAsBytes(resposta.bodyBytes, flush: true);
    return arquivo.path;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _futuroArquivo,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.gold),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  snapshot.error.toString().replaceFirst('Exception: ', ''),
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => setState(() {
                    _futuroArquivo = _baixarPdf(widget.url);
                  }),
                  child: const Text('Tentar novamente'),
                ),
              ],
            ),
          );
        }
        return PDFView(
          filePath: snapshot.data!,
          enableSwipe: true,
          swipeHorizontal: false,
          autoSpacing: true,
          pageFling: true,
          pageSnap: false,
          fitPolicy: FitPolicy.WIDTH,
          backgroundColor: AppColors.card,
        );
      },
    );
  }
}
