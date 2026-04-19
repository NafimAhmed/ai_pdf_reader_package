


import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class PdfAudioReaderState {
  final Uint8List? pdfBytes;
  final String? fileName;
  final String extractedText;
  final String statusMessage;
  final int pageCount;

  final bool isPickingPdf;
  final bool isExtractingText;
  final bool isSpeaking;
  final bool isDocumentLoaded;
  final bool isPdfViewerVisible;

  final double speechRate;
  final double pitch;
  final double volume;
  final String selectedLanguage;

  final int currentChunkIndex;
  final int globalProgressStart;
  final int globalProgressEnd;
  final int lastReadCharacterIndex;

  final String currentWord;
  final String currentPhrase;

  const PdfAudioReaderState({
    this.pdfBytes,
    this.fileName,
    this.extractedText = '',
    this.statusMessage = 'Upload a text-based PDF to start.',
    this.pageCount = 0,
    this.isPickingPdf = false,
    this.isExtractingText = false,
    this.isSpeaking = false,
    this.isDocumentLoaded = false,
    this.isPdfViewerVisible = true,
    this.speechRate = 0.45,
    this.pitch = 1.0,
    this.volume = 1.0,
    this.selectedLanguage = 'en-US',
    this.currentChunkIndex = 0,
    this.globalProgressStart = 0,
    this.globalProgressEnd = 0,
    this.lastReadCharacterIndex = 0,
    this.currentWord = '',
    this.currentPhrase = '',
  });

  bool get hasPdf => pdfBytes != null;
  bool get hasExtractedText => extractedText.trim().isNotEmpty;

  double get progressPercent {
    if (extractedText.isEmpty) return 0;
    return ((lastReadCharacterIndex / extractedText.length) * 100)
        .clamp(0, 100)
        .toDouble();
  }

  PdfAudioReaderState copyWith({
    Uint8List? pdfBytes,
    bool clearPdfBytes = false,
    String? fileName,
    bool clearFileName = false,
    String? extractedText,
    String? statusMessage,
    int? pageCount,
    bool? isPickingPdf,
    bool? isExtractingText,
    bool? isSpeaking,
    bool? isDocumentLoaded,
    bool? isPdfViewerVisible,
    double? speechRate,
    double? pitch,
    double? volume,
    String? selectedLanguage,
    int? currentChunkIndex,
    int? globalProgressStart,
    int? globalProgressEnd,
    int? lastReadCharacterIndex,
    String? currentWord,
    String? currentPhrase,
  }) {
    return PdfAudioReaderState(
      pdfBytes: clearPdfBytes ? null : (pdfBytes ?? this.pdfBytes),
      fileName: clearFileName ? null : (fileName ?? this.fileName),
      extractedText: extractedText ?? this.extractedText,
      statusMessage: statusMessage ?? this.statusMessage,
      pageCount: pageCount ?? this.pageCount,
      isPickingPdf: isPickingPdf ?? this.isPickingPdf,
      isExtractingText: isExtractingText ?? this.isExtractingText,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      isDocumentLoaded: isDocumentLoaded ?? this.isDocumentLoaded,
      isPdfViewerVisible: isPdfViewerVisible ?? this.isPdfViewerVisible,
      speechRate: speechRate ?? this.speechRate,
      pitch: pitch ?? this.pitch,
      volume: volume ?? this.volume,
      selectedLanguage: selectedLanguage ?? this.selectedLanguage,
      currentChunkIndex: currentChunkIndex ?? this.currentChunkIndex,
      globalProgressStart: globalProgressStart ?? this.globalProgressStart,
      globalProgressEnd: globalProgressEnd ?? this.globalProgressEnd,
      lastReadCharacterIndex:
      lastReadCharacterIndex ?? this.lastReadCharacterIndex,
      currentWord: currentWord ?? this.currentWord,
      currentPhrase: currentPhrase ?? this.currentPhrase,
    );
  }
}

class PdfAudioReaderController extends ChangeNotifier {
  PdfAudioReaderController({
    String initialLanguage = 'en-US',
    bool showPdfViewerInitially = true,
  }) : _state = PdfAudioReaderState(
    selectedLanguage: initialLanguage,
    isPdfViewerVisible: showPdfViewerInitially,
  ) {
    _initialize();
  }

  final FlutterTts _tts = FlutterTts();
  final PdfViewerController pdfViewerController = PdfViewerController();

  PdfAudioReaderState _state;
  PdfAudioReaderState get state => _state;

  final List<_SpeechChunk> _ttsChunks = <_SpeechChunk>[];
  PdfTextSearchResult? _searchResult;

  int _speakSession = 0;
  String _lastHighlightedPhrase = '';
  DateTime? _lastHighlightAt;
  DateTime? _lastTextUiAt;

  bool _disposed = false;

  List<Map<String, String>> get supportedLanguages => const <Map<String, String>>[
    {'label': 'English (US)', 'code': 'en-US'},
    {'label': 'Bangla (BD)', 'code': 'bn-BD'},
    {'label': 'Hindi (IN)', 'code': 'hi-IN'},
  ];

  Future<void> _initialize() async {
    await _tts.awaitSpeakCompletion(true);

    _tts.setStartHandler(() {
      _updateState(
        _state.copyWith(
          isSpeaking: true,
        ),
      );
    });

    _tts.setCompletionHandler(() {});

    _tts.setErrorHandler((dynamic message) {
      _updateState(
        _state.copyWith(
          isSpeaking: false,
          statusMessage: 'TTS error: $message',
        ),
      );
    });

    _tts.setProgressHandler((String text, int start, int end, String word) {
      if (_ttsChunks.isEmpty) return;
      if (_state.currentChunkIndex < 0 ||
          _state.currentChunkIndex >= _ttsChunks.length) {
        return;
      }

      final _SpeechChunk currentChunk = _ttsChunks[_state.currentChunkIndex];

      final int globalStart =
      (currentChunk.start + start).clamp(0, _state.extractedText.length);
      final int globalEnd =
      (currentChunk.start + end).clamp(0, _state.extractedText.length);

      final String phrase = _buildHighlightPhrase(globalStart, globalEnd, word);

      final DateTime now = DateTime.now();
      final bool shouldRefreshTextUi =
          _lastTextUiAt == null ||
              now.difference(_lastTextUiAt!).inMilliseconds >= 180 ||
              globalEnd >= _state.extractedText.length;

      if (shouldRefreshTextUi) {
        _lastTextUiAt = now;

        _updateState(
          _state.copyWith(
            globalProgressStart: globalStart,
            globalProgressEnd: globalEnd,
            lastReadCharacterIndex: globalEnd,
            currentWord: word,
            currentPhrase: phrase,
            statusMessage: 'Reading in progress...',
          ),
        );
      }

      _updatePdfHighlight(phrase);
    });

    await _applySpeechSettings();
  }

  Future<void> _applySpeechSettings() async {
    try {
      await _tts.setLanguage(_state.selectedLanguage);
    } catch (_) {}

    await _tts.setSpeechRate(_state.speechRate);
    await _tts.setPitch(_state.pitch);
    await _tts.setVolume(_state.volume);
  }

  void _updateState(PdfAudioReaderState newState) {
    if (_disposed) return;
    _state = newState;
    notifyListeners();
  }

  Future<void> pickPdf() async {
    await stopSpeaking(silent: true, resetProgress: false);

    _updateState(
      _state.copyWith(
        isPickingPdf: true,
        isDocumentLoaded: false,
        statusMessage: 'Opening file picker...',
      ),
    );

    _clearPdfHighlight();

    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: <String>['pdf'],
        withData: true,
      );

      if (result == null) {
        _updateState(
          _state.copyWith(
            isPickingPdf: false,
            statusMessage: 'No file selected.',
          ),
        );
        return;
      }

      final PlatformFile file = result.files.single;

      if (file.bytes == null || file.bytes!.isEmpty) {
        _updateState(
          _state.copyWith(
            isPickingPdf: false,
            statusMessage: 'Could not read PDF bytes.',
          ),
        );
        return;
      }

      await loadPdfFromBytes(
        file.bytes!,
        fileName: file.name,
      );
    } catch (e) {
      _updateState(
        _state.copyWith(
          statusMessage: 'Failed to open PDF: $e',
        ),
      );
    } finally {
      _updateState(
        _state.copyWith(
          isPickingPdf: false,
        ),
      );
    }
  }

  Future<void> loadPdfFromBytes(
      Uint8List bytes, {
        String? fileName,
      }) async {
    await stopSpeaking(silent: true, resetProgress: true);
    _clearPdfHighlight();

    _ttsChunks.clear();

    _updateState(
      _state.copyWith(
        pdfBytes: bytes,
        fileName: fileName,
        extractedText: '',
        pageCount: 0,
        currentChunkIndex: 0,
        globalProgressStart: 0,
        globalProgressEnd: 0,
        lastReadCharacterIndex: 0,
        currentWord: '',
        currentPhrase: '',
        isDocumentLoaded: false,
        statusMessage: 'PDF loaded. Extracting text...',
      ),
    );

    await _extractTextFromPdf();
  }

  Future<void> _extractTextFromPdf() async {
    if (_state.pdfBytes == null) return;

    _updateState(
      _state.copyWith(
        isExtractingText: true,
      ),
    );

    try {
      final PdfDocument document = PdfDocument(inputBytes: _state.pdfBytes!);
      final PdfTextExtractor extractor = PdfTextExtractor(document);

      final String rawText = extractor.extractText();
      final int pageCount = document.pages.count;

      document.dispose();

      final String cleanedText = _cleanExtractedText(rawText);

      if (cleanedText.trim().isEmpty) {
        _updateState(
          _state.copyWith(
            pageCount: pageCount,
            extractedText: cleanedText,
            isExtractingText: false,
            statusMessage:
            'No readable text found. This PDF may be scan/image-based.',
          ),
        );
      } else {
        _updateState(
          _state.copyWith(
            pageCount: pageCount,
            extractedText: cleanedText,
            isExtractingText: false,
            statusMessage: 'Text extracted successfully from $pageCount page(s).',
          ),
        );
      }
    } catch (e) {
      _updateState(
        _state.copyWith(
          isExtractingText: false,
          statusMessage: 'Text extraction failed: $e',
        ),
      );
    }
  }

  Future<void> startSpeaking() async {
    if (_state.extractedText.trim().isEmpty) {
      _updateState(
        _state.copyWith(
          statusMessage: 'No text available to read. Upload a text-based PDF first.',
        ),
      );
      return;
    }

    await _applySpeechSettings();

    _ttsChunks
      ..clear()
      ..addAll(_buildSpeechChunks(_state.extractedText));

    if (_ttsChunks.isEmpty) {
      _updateState(
        _state.copyWith(
          statusMessage: 'No valid text chunk found for speech.',
        ),
      );
      return;
    }

    _clearPdfHighlight();

    _updateState(
      _state.copyWith(
        globalProgressStart: 0,
        globalProgressEnd: 0,
        lastReadCharacterIndex: 0,
        currentWord: '',
        currentPhrase: '',
        currentChunkIndex: 0,
        isSpeaking: true,
        statusMessage: 'Reading started...',
      ),
    );

    final int currentSession = ++_speakSession;

    try {
      for (int i = 0; i < _ttsChunks.length; i++) {
        if (_disposed || currentSession != _speakSession) {
          break;
        }

        _updateState(
          _state.copyWith(
            currentChunkIndex: i,
          ),
        );

        await _tts.speak(_ttsChunks[i].text);
      }

      if (_disposed) return;

      if (currentSession == _speakSession) {
        _updateState(
          _state.copyWith(
            isSpeaking: false,
            globalProgressStart: 0,
            globalProgressEnd: _state.extractedText.length,
            lastReadCharacterIndex: _state.extractedText.length,
            currentWord: '',
            currentPhrase: '',
            statusMessage: 'Reading finished.',
          ),
        );
      }
    } catch (e) {
      _updateState(
        _state.copyWith(
          isSpeaking: false,
          statusMessage: 'Reading failed: $e',
        ),
      );
    }
  }

  Future<void> stopSpeaking({
    bool silent = false,
    bool resetProgress = false,
  }) async {
    _speakSession++;
    await _tts.stop();

    _updateState(
      _state.copyWith(
        isSpeaking: false,
        currentChunkIndex: 0,
        statusMessage: silent ? _state.statusMessage : 'Reading stopped.',
        globalProgressStart: resetProgress ? 0 : _state.globalProgressStart,
        globalProgressEnd: resetProgress ? 0 : _state.globalProgressEnd,
        lastReadCharacterIndex:
        resetProgress ? 0 : _state.lastReadCharacterIndex,
        currentWord: resetProgress ? '' : _state.currentWord,
        currentPhrase: resetProgress ? '' : _state.currentPhrase,
      ),
    );
  }

  Future<void> setLanguage(String languageCode) async {
    _updateState(
      _state.copyWith(
        selectedLanguage: languageCode,
      ),
    );
    await _applySpeechSettings();
  }

  Future<void> setSpeechRate(double value) async {
    _updateState(
      _state.copyWith(
        speechRate: value,
      ),
    );
    await _tts.setSpeechRate(value);
  }

  Future<void> setPitch(double value) async {
    _updateState(
      _state.copyWith(
        pitch: value,
      ),
    );
    await _tts.setPitch(value);
  }

  Future<void> setVolume(double value) async {
    _updateState(
      _state.copyWith(
        volume: value,
      ),
    );
    await _tts.setVolume(value);
  }

  void setPdfViewerVisible(bool value) {
    _updateState(
      _state.copyWith(
        isPdfViewerVisible: value,
      ),
    );
  }

  void onPdfDocumentLoaded(int pageCount) {
    _updateState(
      _state.copyWith(
        isDocumentLoaded: true,
        pageCount: pageCount,
      ),
    );
  }

  void onPdfDocumentLoadFailed(String error) {
    _updateState(
      _state.copyWith(
        isDocumentLoaded: false,
        statusMessage: 'PDF load failed: $error',
      ),
    );
  }

  String _cleanExtractedText(String value) {
    return value
        .replaceAll('\r', '')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  List<String> _splitTextIntoChunks(String text, {int maxChars = 2200}) {
    final String normalized = text.trim();
    if (normalized.isEmpty) return <String>[];

    final List<String> units = normalized.split(
      RegExp(r'(?<=[.!?।])\s+|\n{2,}'),
    );

    final List<String> chunks = <String>[];
    final StringBuffer buffer = StringBuffer();

    for (final String rawUnit in units) {
      final String unit = rawUnit.trim();
      if (unit.isEmpty) continue;

      if (unit.length > maxChars) {
        if (buffer.isNotEmpty) {
          chunks.add(buffer.toString().trim());
          buffer.clear();
        }

        int start = 0;
        while (start < unit.length) {
          final int end =
          (start + maxChars < unit.length) ? start + maxChars : unit.length;
          chunks.add(unit.substring(start, end).trim());
          start = end;
        }
        continue;
      }

      final String candidate =
      buffer.isEmpty ? unit : '${buffer.toString()} $unit';

      if (candidate.length <= maxChars) {
        buffer
          ..clear()
          ..write(candidate);
      } else {
        chunks.add(buffer.toString().trim());
        buffer
          ..clear()
          ..write(unit);
      }
    }

    if (buffer.isNotEmpty) {
      chunks.add(buffer.toString().trim());
    }

    return chunks.where((String e) => e.isNotEmpty).toList();
  }

  List<_SpeechChunk> _buildSpeechChunks(String fullText) {
    final List<String> pieces = _splitTextIntoChunks(fullText);
    final List<_SpeechChunk> chunks = <_SpeechChunk>[];

    int searchFrom = 0;

    for (final String piece in pieces) {
      final int foundIndex = fullText.indexOf(piece, searchFrom);
      final int startIndex = foundIndex >= 0 ? foundIndex : searchFrom;

      chunks.add(_SpeechChunk(
        text: piece,
        start: startIndex,
      ));

      searchFrom = startIndex + piece.length;
    }

    return chunks;
  }

  String _buildHighlightPhrase(int globalStart, int globalEnd, String word) {
    if (_state.extractedText.isEmpty) return '';

    int left = globalStart;
    int right = globalEnd;

    int leftBoundaries = 0;
    while (left > 0 && leftBoundaries < 4) {
      left--;
      if (_isWhitespace(_state.extractedText.codeUnitAt(left))) {
        leftBoundaries++;
      }
    }

    int rightBoundaries = 0;
    while (right < _state.extractedText.length && rightBoundaries < 4) {
      if (_isWhitespace(_state.extractedText.codeUnitAt(right))) {
        rightBoundaries++;
      }
      right++;
    }

    String phrase = _state.extractedText.substring(left, right);
    phrase = phrase.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (phrase.length < 3) {
      phrase = word.replaceAll(RegExp(r'\s+'), ' ').trim();
    }

    if (phrase.length > 100) {
      phrase = phrase.substring(0, 100).trim();
    }

    return phrase;
  }

  bool _isWhitespace(int codeUnit) {
    return codeUnit == 32 || codeUnit == 10 || codeUnit == 13 || codeUnit == 9;
  }

  void _updatePdfHighlight(String phrase) {
    if (!_state.isDocumentLoaded) return;

    final String normalized = phrase.trim();
    if (normalized.isEmpty) return;

    final DateTime now = DateTime.now();

    if (_lastHighlightedPhrase == normalized) {
      return;
    }

    if (_lastHighlightAt != null &&
        now.difference(_lastHighlightAt!).inMilliseconds < 700) {
      return;
    }

    _lastHighlightAt = now;
    _lastHighlightedPhrase = normalized;

    try {
      _searchResult?.clear();
    } catch (_) {}

    _searchResult = pdfViewerController.searchText(normalized);
  }

  void _clearPdfHighlight() {
    try {
      _searchResult?.clear();
    } catch (_) {}

    _lastHighlightedPhrase = '';
    _lastHighlightAt = null;
  }

  @override
  void dispose() {
    _disposed = true;
    _tts.stop();
    try {
      _searchResult?.clear();
    } catch (_) {}
    super.dispose();
  }
}

class PdfAudioReaderView extends StatefulWidget {
  const PdfAudioReaderView({
    super.key,
    required this.controller,
    this.allowPdfViewerToggle = true,
    this.showUploadButton = true,
    this.showProgressText = true,
    this.emptyTitle = 'Upload a PDF file',
    this.emptySubtitle =
    'The package will open the PDF and show reading progress below.',
  });

  final PdfAudioReaderController controller;
  final bool allowPdfViewerToggle;
  final bool showUploadButton;
  final bool showProgressText;
  final String emptyTitle;
  final String emptySubtitle;

  @override
  State<PdfAudioReaderView> createState() => _PdfAudioReaderViewState();
}

class _PdfAudioReaderViewState extends State<PdfAudioReaderView> {
  final ScrollController _textScrollController = ScrollController();
  int _lastAutoScrollIndex = -1;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerUpdate);
  }

  @override
  void didUpdateWidget(covariant PdfAudioReaderView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerUpdate);
      widget.controller.addListener(_handleControllerUpdate);
    }
  }

  void _handleControllerUpdate() {
    final PdfAudioReaderState state = widget.controller.state;

    if (state.lastReadCharacterIndex != _lastAutoScrollIndex) {
      _lastAutoScrollIndex = state.lastReadCharacterIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollTextToCurrentProgress(state);
      });
    }
  }

  void _scrollTextToCurrentProgress(PdfAudioReaderState state) {
    if (!_textScrollController.hasClients) return;
    if (state.extractedText.isEmpty) return;

    final double ratio = state.lastReadCharacterIndex <= 0
        ? 0
        : (state.lastReadCharacterIndex / state.extractedText.length)
        .clamp(0.0, 1.0);

    final double maxExtent = _textScrollController.position.maxScrollExtent;
    final double target = (maxExtent * ratio - 120).clamp(0.0, maxExtent);

    _textScrollController.jumpTo(target);
  }

  TextSpan _buildProgressTextSpan(
      BuildContext context,
      PdfAudioReaderState state,
      ) {
    final TextStyle baseStyle = Theme.of(context).textTheme.bodyMedium!.copyWith(
      fontSize: 15,
      height: 1.6,
      color: Colors.black87,
    );

    if (state.extractedText.isEmpty) {
      return TextSpan(
        text: 'No extracted text yet.',
        style: baseStyle,
      );
    }

    final int safeStart =
    state.globalProgressStart.clamp(0, state.extractedText.length);
    final int safeEnd =
    state.globalProgressEnd.clamp(0, state.extractedText.length);

    if (safeEnd <= 0) {
      return TextSpan(
        text: state.extractedText,
        style: baseStyle,
      );
    }

    final String readBeforeCurrent = state.extractedText.substring(0, safeStart);
    final String currentWordPart =
    state.extractedText.substring(safeStart, safeEnd);
    final String unreadAfter = state.extractedText.substring(safeEnd);

    return TextSpan(
      style: baseStyle,
      children: <InlineSpan>[
        TextSpan(
          text: readBeforeCurrent,
          style: baseStyle.copyWith(
            color: Colors.green.shade700,
            fontWeight: FontWeight.w600,
          ),
        ),
        TextSpan(
          text: currentWordPart,
          style: baseStyle.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            backgroundColor: Colors.green.shade600,
          ),
        ),
        TextSpan(
          text: unreadAfter,
          style: baseStyle.copyWith(
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildTopControlPanel(
      BuildContext context,
      PdfAudioReaderState state, {
        required bool busy,
      }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            if (widget.showUploadButton)
              ElevatedButton.icon(
                onPressed: busy ? null : widget.controller.pickPdf,
                icon: const Icon(Icons.upload_file),
                label: Text(
                  state.isPickingPdf ? 'Opening...' : 'Upload PDF',
                ),
              ),
            ElevatedButton.icon(
              onPressed: (!state.hasExtractedText || state.isSpeaking)
                  ? null
                  : widget.controller.startSpeaking,
              icon: const Icon(Icons.volume_up),
              label: const Text('Read Aloud'),
            ),
            ElevatedButton.icon(
              onPressed:
              state.isSpeaking ? () => widget.controller.stopSpeaking() : null,
              icon: const Icon(Icons.stop_circle),
              label: const Text('Stop'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (widget.allowPdfViewerToggle)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Show PDF Viewer'),
            value: state.isPdfViewerVisible,
            onChanged: widget.controller.setPdfViewerVisible,
          ),
        if (state.fileName != null) ...<Widget>[
          Text(
            'File: ${state.fileName}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            _InfoChip(label: 'Pages', value: state.pageCount.toString()),
            _InfoChip(label: 'Chars', value: state.extractedText.length.toString()),
            _InfoChip(
              label: 'Read',
              value: '${state.progressPercent.toStringAsFixed(1)}%',
            ),
            _InfoChip(
              label: 'Last Index',
              value: state.lastReadCharacterIndex.toString(),
            ),
          ],
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          value: state.selectedLanguage,
          decoration: const InputDecoration(
            labelText: 'Speech Language',
            border: OutlineInputBorder(),
          ),
          items: widget.controller.supportedLanguages.map((Map<String, String> item) {
            return DropdownMenuItem<String>(
              value: item['code'],
              child: Text(item['label']!),
            );
          }).toList(),
          onChanged: busy
              ? null
              : (String? value) async {
            if (value == null) return;
            await widget.controller.setLanguage(value);
          },
        ),
        const SizedBox(height: 14),
        Text('Speech Rate: ${state.speechRate.toStringAsFixed(2)}'),
        Slider(
          value: state.speechRate,
          min: 0.20,
          max: 0.70,
          divisions: 10,
          onChanged: busy
              ? null
              : (double value) {
            widget.controller.setSpeechRate(value);
          },
        ),
        Text('Pitch: ${state.pitch.toStringAsFixed(2)}'),
        Slider(
          value: state.pitch,
          min: 0.50,
          max: 1.50,
          divisions: 10,
          onChanged: busy
              ? null
              : (double value) {
            widget.controller.setPitch(value);
          },
        ),
        Text('Volume: ${state.volume.toStringAsFixed(2)}'),
        Slider(
          value: state.volume,
          min: 0.0,
          max: 1.0,
          divisions: 10,
          onChanged: busy
              ? null
              : (double value) {
            widget.controller.setVolume(value);
          },
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(state.statusMessage),
        ),
        if (state.currentWord.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            'Current word: ${state.currentWord}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ],
    );
  }

  Widget _buildProgressCard(BuildContext context, PdfAudioReaderState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Reading Progress Text',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey.shade50,
                  border: Border.all(
                    color: Colors.black12,
                  ),
                ),
                child: SingleChildScrollView(
                  controller: _textScrollController,
                  child: SelectableText.rich(
                    _buildProgressTextSpan(context, state),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Card(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.picture_as_pdf, size: 72),
              const SizedBox(height: 16),
              Text(
                widget.emptyTitle,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.emptySubtitle,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerUpdate);
    _textScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (BuildContext context, _) {
        final PdfAudioReaderState state = widget.controller.state;
        final bool busy = state.isPickingPdf || state.isExtractingText;

        return LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double controlPanelHeight =
            (constraints.maxHeight * 0.38).clamp(250.0, 390.0);

            return Column(
              children: <Widget>[
                SizedBox(
                  height: controlPanelHeight,
                  child: Card(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(14),
                      child: _buildTopControlPanel(
                        context,
                        state,
                        busy: busy,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: !state.hasPdf
                      ? _buildEmptyState()
                      : state.isPdfViewerVisible
                      ? Column(
                    children: <Widget>[
                      Expanded(
                        flex: 5,
                        child: Card(
                          clipBehavior: Clip.antiAlias,
                          child: SfPdfViewer.memory(
                            state.pdfBytes!,
                            controller:
                            widget.controller.pdfViewerController,
                            currentSearchTextHighlightColor:
                            Colors.green.withOpacity(0.78),
                            otherSearchTextHighlightColor:
                            Colors.green.withOpacity(0.22),
                            onDocumentLoaded:
                                (PdfDocumentLoadedDetails details) {
                              widget.controller.onPdfDocumentLoaded(
                                details.document.pages.count,
                              );
                            },
                            onDocumentLoadFailed:
                                (PdfDocumentLoadFailedDetails details) {
                              widget.controller.onPdfDocumentLoadFailed(
                                details.error,
                              );
                            },
                          ),
                        ),
                      ),
                      if (widget.showProgressText) ...<Widget>[
                        const SizedBox(height: 12),
                        Expanded(
                          flex: 3,
                          child: _buildProgressCard(context, state),
                        ),
                      ],
                    ],
                  )
                      : widget.showProgressText
                      ? _buildProgressCard(context, state)
                      : _buildEmptyState(),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label: $value'),
    );
  }
}

class _SpeechChunk {
  final String text;
  final int start;

  const _SpeechChunk({
    required this.text,
    required this.start,
  });
}