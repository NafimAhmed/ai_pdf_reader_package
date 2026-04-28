



import 'package:ai_pdf_reader/ai_pdf_reader.dart';
import 'package:flutter/material.dart';


void main() {
  runApp(const PdfAudioReaderExampleApp());
}

class PdfAudioReaderExampleApp extends StatelessWidget {
  const PdfAudioReaderExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PDF Audio Reader Example',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.green,
      ),
      home: const ExampleHomePage(),
    );
  }
}

class ExampleHomePage extends StatefulWidget {
  const ExampleHomePage({super.key});

  @override
  State<ExampleHomePage> createState() => _ExampleHomePageState();
}

class _ExampleHomePageState extends State<ExampleHomePage> {
  late final PdfAudioReaderController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PdfAudioReaderController(
      initialLanguage: 'en-US',
      showPdfViewerInitially: true,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final state = _controller.state;

        return Scaffold(
          appBar: AppBar(
            title: const Text('PDF Audio Reader Example'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withOpacity(0.18)),
                  ),
                  child: Text(
                    'Last Read Character Index: ${state.lastReadCharacterIndex}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                Expanded(
                  child: PdfAudioReaderView(
                    controller: _controller,
                    allowPdfViewerToggle: true,
                    showUploadButton: true,
                    showProgressText: true,
                    emptyTitle: 'Upload a PDF',
                    emptySubtitle:
                    'Pick a PDF file, extract text, and read it aloud.',
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}