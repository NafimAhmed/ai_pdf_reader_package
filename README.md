

# AI PDF Reader

A powerful Flutter package for loading PDF files, extracting readable text, playing the content with text-to-speech, highlighting reading progress, and tracking the **last read character index** in real time.

This package is designed for developers who want to add a clean and interactive **PDF audio reader experience** to their Flutter apps with minimal setup.

---

## ✨ Features

- 📄 Upload and load PDF files
- 🔍 Extract text from text-based PDFs
- 🔊 Read PDF content aloud using Text-to-Speech
- 🟢 Highlight current reading progress in text view
- 📌 Track the **last read character index**
- 👁️ Optional built-in PDF viewer
- 🎚️ Adjustable speech rate, pitch, and volume
- 🌍 Language selection support
- 📊 Show PDF details like:
    - file name
    - page count
    - character count
    - reading percentage
    - last read character index
- 🧩 Reusable controller-based architecture
- 📱 Easy integration inside any Flutter app
- Generate offline extractive summaries from PDF text
- Works without a backend for text extraction and local summary generation

---

## 📸 What This Package Provides

With `ai_pdf_reader`, users can:

- pick a PDF file from device storage
- view PDF details instantly
- listen to the extracted text as audio
- see live reading progress
- optionally show or hide the PDF viewer
- monitor the exact character position reached during reading

This makes it ideal for:

- accessibility-focused apps
- study apps
- reading assistant apps
- document reader apps
- productivity tools

---

## 🚀 Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  ai_pdf_reader: ^0.0.5

```

Then run: 
```bash
flutter pub get
```

Import the package in your Dart file:

```dart
import 'package:ai_pdf_reader/pdf_audio_reader.dart';
```
Create a controller:

```dart

late final PdfAudioReaderController controller;

@override
void initState() {
  super.initState();
  controller = PdfAudioReaderController(
    initialLanguage: 'en-US',
    showPdfViewerInitially: true,
  );
}

@override
void dispose() {
  controller.dispose();
  super.dispose();
}
```

Attach the package widget to your screen:

```dart

import 'package:flutter/material.dart';
import 'package:ai_pdf_reader/pdf_audio_reader.dart';

class DemoPage extends StatefulWidget {
  const DemoPage({super.key});

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  late final PdfAudioReaderController controller;

  @override
  void initState() {
    super.initState();
    controller = PdfAudioReaderController(
      initialLanguage: 'en-US',
      showPdfViewerInitially: true,
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI PDF Reader'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: PdfAudioReaderView(
          controller: controller,
          allowPdfViewerToggle: true,
          showUploadButton: true,
          showProgressText: true,
        ),
      ),
    );
  }
}

```
## Example

```dart
import 'package:flutter/material.dart';
import 'package:ai_pdf_reader/pdf_audio_reader.dart';

class DemoPage extends StatefulWidget {
  const DemoPage({super.key});

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  late final PdfAudioReaderController controller;

  @override
  void initState() {
    super.initState();
    controller = PdfAudioReaderController(
      initialLanguage: 'en-US',
      showPdfViewerInitially: true,
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI PDF Reader'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: PdfAudioReaderView(
          controller: controller,
          allowPdfViewerToggle: true,
          showUploadButton: true,
          showProgressText: true,
        ),
      ),
    );
  }
}
```
 
## Access Reading Progress

You can access the current reading state directly from the controller.

Get the last read character index:

```dart
final int lastIndex = controller.state.lastReadCharacterIndex;
```
Get reading percentage:
```dart
final double progress = controller.state.progressPercent;
```

Get extracted text:
```dart
final String text = controller.state.extractedText;
```

Check whether audio is currently playing

```dart
final bool isSpeaking = controller.state.isSpeaking;
```

It can also generate offline PDF Summery

```dart
final String summary = LocalPdfSummarizer.summarize(
  controller.state.extractedText,
  maxSentences: 5,
);

print(summary);

```

# Built-in Controls

The package includes built-in controls for:

- Upload PDF
- Read Aloud
- Stop Reading
- Show / Hide PDF Viewer
- Change Language
- Adjust Speech Rate
- Adjust Pitch
- Adjust Volume

# UI Highlights

The built-in widget includes:

- an attractive top control panel
- PDF details section
- optional PDF viewer
- reading progress section
- live highlighted spoken text
- current word display
- last read character index display