import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:harismruti/api/models/gallery_models.dart';
import 'package:harismruti/api/repositories/gallery_repository.dart';
import 'package:harismruti/ui/view/gallery/gallery_detail_screen.dart';
import 'package:harismruti/utils/app_color.dart';
import 'package:harismruti/utils/storage_helper.dart';
import 'package:harismruti/widget/appbar/detail_appbar.dart';
import 'package:harismruti/widget/background/custom_background.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class _AiChatTurn {
  _AiChatTurn({required this.id, required this.prompt, required this.createdAt})
    : photos = const [],
      error = null,
      isSearching = true;

  final int id;
  final String prompt;
  final DateTime createdAt;
  List<GalleryPhoto> photos;
  String? error;
  bool isSearching;
}

class _AiHistoryItem {
  const _AiHistoryItem({
    required this.prompt,
    required this.createdAt,
    required this.resultCount,
  });

  final String prompt;
  final DateTime createdAt;
  final int resultCount;

  Map<String, dynamic> toJson() => {
    'prompt': prompt,
    'created_at': createdAt.toIso8601String(),
    'result_count': resultCount,
  };
}

class AiSmrutiSearchScreen extends StatefulWidget {
  const AiSmrutiSearchScreen({super.key});

  @override
  State<AiSmrutiSearchScreen> createState() => _AiSmrutiSearchScreenState();
}

class _AiSmrutiSearchScreenState extends State<AiSmrutiSearchScreen>
    with SingleTickerProviderStateMixin {
  static const _suggestions = <String>[
    'Hariprasad Swamiji in car',
    'Guru Hari with children',
    'Swamiji morning walk',
    'Swamiji sunset walk',
  ];

  final GalleryRepository _repository = const GalleryRepository();
  final TextEditingController _promptController = TextEditingController();
  final FocusNode _promptFocus = FocusNode();
  final ScrollController _chatScrollController = ScrollController();
  final SpeechToText _speech = SpeechToText();
  late final AnimationController _pulseController;

  final List<_AiChatTurn> _turns = [];
  List<_AiHistoryItem> _history = const [];
  List<LocaleName> _locales = const [];
  String? _localeId;
  bool _isSearching = false;
  bool _speechReady = false;
  String? _speechError;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _loadHistory();
    _prepareSpeech();
  }

  @override
  void dispose() {
    _speech.stop();
    _pulseController.dispose();
    _promptController.dispose();
    _promptFocus.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  Future<void> _prepareSpeech() async {
    final ready = await _speech.initialize(
      onStatus: (_) {
        if (mounted) setState(() {});
      },
      onError: (error) {
        if (!mounted) return;
        setState(() => _speechError = error.errorMsg);
      },
    );
    if (!ready || !mounted) return;
    final installedLocales = await _speech.locales();
    final locales = installedLocales.where((locale) {
      final language = locale.localeId
          .toLowerCase()
          .split(RegExp('[-_]'))
          .first;
      return language == 'en' || language == 'gu';
    }).toList();
    final systemLocale = await _speech.systemLocale();
    if (!mounted) return;
    final systemLocaleId = systemLocale?.localeId;
    final selectedLocale =
        locales.any((locale) => locale.localeId == systemLocaleId)
        ? systemLocaleId
        : locales
              .where((locale) => locale.localeId.toLowerCase().startsWith('en'))
              .map((locale) => locale.localeId)
              .firstOrNull;
    setState(() {
      _speechReady = true;
      _locales = locales;
      _localeId = selectedLocale ?? locales.firstOrNull?.localeId;
    });
  }

  Future<void> _toggleListening() async {
    if (_speech.isListening) {
      await _speech.stop();
      if (mounted) setState(() {});
      return;
    }
    if (!_speechReady) {
      await _prepareSpeech();
      if (!_speechReady) {
        if (mounted) {
          setState(() => _speechError = 'Microphone permission is required.');
        }
        return;
      }
    }
    _promptFocus.unfocus();
    await _speech.listen(
      onResult: _onSpeechResult,
      listenOptions: SpeechListenOptions(
        localeId: _localeId,
        listenMode: ListenMode.dictation,
        partialResults: true,
      ),
    );
    if (mounted) setState(() {});
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    _promptController.text = result.recognizedWords;
    _promptController.selection = TextSelection.collapsed(
      offset: _promptController.text.length,
    );
  }

  Future<void> _chooseLanguage() async {
    if (!_speechReady) await _prepareSpeech();
    if (!mounted || _locales.isEmpty) return;
    final chosen = await showModalBottomSheet<LocaleName>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView.builder(
          itemCount: _locales.length,
          itemBuilder: (context, index) {
            final locale = _locales[index];
            return ListTile(
              leading: Icon(
                locale.localeId == _localeId
                    ? CupertinoIcons.checkmark_circle_fill
                    : CupertinoIcons.globe,
                color: locale.localeId == _localeId ? primaryColor : null,
              ),
              title: Text(locale.name),
              subtitle: Text(locale.localeId),
              onTap: () => Navigator.pop(context, locale),
            );
          },
        ),
      ),
    );
    if (chosen != null && mounted) {
      setState(() => _localeId = chosen.localeId);
    }
  }

  Future<void> _search([String? suggestedPrompt]) async {
    final prompt = (suggestedPrompt ?? _promptController.text).trim();
    if (prompt.length < 2 || _isSearching) return;
    if (_speech.isListening) await _speech.stop();
    _promptController.clear();
    _promptFocus.unfocus();
    final turn = _AiChatTurn(
      id: DateTime.now().microsecondsSinceEpoch,
      prompt: prompt,
      createdAt: DateTime.now(),
    );
    setState(() {
      _turns.add(turn);
      _isSearching = true;
      _speechError = null;
    });
    _scrollToBottom();
    try {
      final photos = await _repository.naturalSearch(prompt, limit: 80);
      if (!mounted) return;
      setState(() => turn.photos = photos);
      _saveHistory(prompt, photos.length, turn.createdAt);
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        turn.error = 'I could not search these smrutis. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          turn.isSearching = false;
          _isSearching = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_chatScrollController.hasClients) return;
      _chatScrollController.animateTo(
        _chatScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _openPhoto(List<GalleryPhoto> photos, int index) {
    Navigator.push(
      context,
      CupertinoPageRoute<void>(
        builder: (_) => GalleryFullscreenViewer(
          photos: photos,
          initialIndex: index,
          title: 'AI Smruti Search',
        ),
      ),
    );
  }

  void _openAllResults(_AiChatTurn turn) {
    final photos = List<GalleryPhoto>.unmodifiable(turn.photos);
    Navigator.push(
      context,
      CupertinoPageRoute<void>(
        builder: (_) => GalleryDetailScreen(
          title: 'AI Smruti Results',
          subtitle: turn.prompt,
          loader: () async => photos,
        ),
      ),
    );
  }

  void _loadHistory() {
    final raw = StorageHelper.getValue<List>(key: StorageKeys.aiSearchHistory);
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final items = (raw ?? const [])
        .whereType<Map>()
        .map((item) {
          final data = Map<String, dynamic>.from(item);
          final createdAt = DateTime.tryParse(
            data['created_at']?.toString() ?? '',
          );
          final prompt = data['prompt']?.toString().trim() ?? '';
          if (createdAt == null ||
              prompt.isEmpty ||
              createdAt.isBefore(cutoff)) {
            return null;
          }
          return _AiHistoryItem(
            prompt: prompt,
            createdAt: createdAt,
            resultCount:
                int.tryParse(data['result_count']?.toString() ?? '') ?? 0,
          );
        })
        .whereType<_AiHistoryItem>()
        .take(50)
        .toList();
    _history = items;
    StorageHelper.setValue(
      key: StorageKeys.aiSearchHistory,
      value: items.map((item) => item.toJson()).toList(),
    );
  }

  void _saveHistory(String prompt, int resultCount, DateTime createdAt) {
    final updated = [
      _AiHistoryItem(
        prompt: prompt,
        createdAt: createdAt,
        resultCount: resultCount,
      ),
      ..._history.where(
        (item) => item.prompt.toLowerCase() != prompt.toLowerCase(),
      ),
    ].take(50).toList();
    setState(() => _history = updated);
    StorageHelper.setValue(
      key: StorageKeys.aiSearchHistory,
      value: updated.map((item) => item.toJson()).toList(),
    );
  }

  void _deleteHistory(int index) {
    final updated = [..._history]..removeAt(index);
    setState(() => _history = updated);
    StorageHelper.setValue(
      key: StorageKeys.aiSearchHistory,
      value: updated.map((item) => item.toJson()).toList(),
    );
  }

  void _clearHistory() {
    setState(() {
      _history = const [];
      _turns.clear();
    });
    StorageHelper.removeValue(StorageKeys.aiSearchHistory);
    Navigator.pop(context);
  }

  String get _languageLabel {
    for (final locale in _locales) {
      if (locale.localeId == _localeId) return locale.name;
    }
    return 'Language';
  }

  Future<void> _showHistory() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, refreshSheet) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.7,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 8, 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Search history',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (_history.isNotEmpty)
                        TextButton(
                          onPressed: _clearHistory,
                          child: const Text('Clear all'),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: _history.isEmpty
                      ? const Center(child: Text('No saved searches yet'))
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                          itemCount: _history.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = _history[index];
                            return ListTile(
                              leading: const Icon(CupertinoIcons.clock),
                              title: Text(
                                item.prompt,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '${item.resultCount} smrutis · ${_historyDate(item.createdAt)}',
                              ),
                              trailing: IconButton(
                                tooltip: 'Delete',
                                icon: const Icon(CupertinoIcons.delete),
                                onPressed: () {
                                  _deleteHistory(index);
                                  refreshSheet(() {});
                                },
                              ),
                              onTap: () {
                                Navigator.pop(sheetContext);
                                _search(item.prompt);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _historyDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CustomBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: DetailAppbar(
          title: 'AI Smruti Search',
          actions: [
            IconButton(
              tooltip: 'Search history',
              onPressed: _showHistory,
              icon: Badge(
                isLabelVisible: _history.isNotEmpty,
                smallSize: 7,
                child: const Icon(CupertinoIcons.clock_fill),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(
          children: [
            Expanded(child: _buildChatList(scheme)),
            _PromptComposer(
              controller: _promptController,
              focusNode: _promptFocus,
              isListening: _speech.isListening,
              isSearching: _isSearching,
              languageLabel: _languageLabel,
              onLanguage: _chooseLanguage,
              onMic: _toggleListening,
              onSend: _search,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatList(ColorScheme scheme) {
    final topPadding = MediaQuery.paddingOf(context).top + kToolbarHeight + 20;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: _turns.isEmpty
          ? SingleChildScrollView(
              key: const ValueKey('ai-welcome'),
              padding: EdgeInsets.fromLTRB(16, topPadding, 16, 20),
              child: _buildWelcome(scheme),
            )
          : ListView.builder(
              key: const ValueKey('ai-chat'),
              controller: _chatScrollController,
              padding: EdgeInsets.fromLTRB(16, topPadding, 16, 20),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              cacheExtent: 650,
              itemCount: _turns.length,
              itemBuilder: (context, index) {
                final turn = _turns[index];
                return RepaintBoundary(
                  key: ValueKey(turn.id),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) => Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 12 * (1 - value)),
                        child: child,
                      ),
                    ),
                    child: _buildChatTurn(turn, scheme),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildChatTurn(_AiChatTurn turn, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 310),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(5),
                ),
              ),
              child: Text(
                turn.prompt,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 18),
          AnimatedSize(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: turn.isSearching
                ? _SearchingReply(animation: _pulseController)
                : turn.error != null
                ? _AssistantMessage(text: turn.error!)
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _AssistantMessage(
                        text: turn.photos.isEmpty
                            ? 'I could not find a matching smruti. Try describing the person, place, activity, or time differently.'
                            : 'I found ${turn.photos.length} matching smrutis for you.',
                      ),
                      if (turn.photos.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _ChatImagePreview(
                          photos: turn.photos,
                          imageHeaders: _repository.imageHeaders,
                          onPhotoTap: (index) => _openPhoto(turn.photos, index),
                          onViewAll: () => _openAllResults(turn),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcome(ColorScheme scheme) {
    return Column(
      key: const ValueKey('welcome'),
      children: [
        const SizedBox(height: 18),
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) => Transform.scale(
            scale: 0.96 + (_pulseController.value * 0.06),
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [primaryColor, const Color(0xFFE7A46B)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withAlpha(
                      35 + (_pulseController.value * 45).round(),
                    ),
                    blurRadius: 24,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
                CupertinoIcons.sparkles,
                color: Colors.white,
                size: 38,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'What smruti would you like to see?',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: scheme.onSurface,
            fontSize: 25,
            height: 1.15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Type or speak naturally in English or Gujarati.',
          textAlign: TextAlign.center,
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 15),
        ),
        const SizedBox(height: 28),
        ..._suggestions.map(
          (prompt) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => _search(prompt),
              child: Ink(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 15,
                ),
                decoration: BoxDecoration(
                  color: scheme.surface.withAlpha(205),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.sparkles,
                      color: primaryColor,
                      size: 19,
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(prompt)),
                    const Icon(CupertinoIcons.arrow_up_right, size: 17),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_speechError != null) ...[
          const SizedBox(height: 8),
          Text(
            _speechError!,
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.error),
          ),
        ],
      ],
    );
  }
}

class _ChatImagePreview extends StatelessWidget {
  const _ChatImagePreview({
    required this.photos,
    required this.imageHeaders,
    required this.onPhotoTap,
    required this.onViewAll,
  });

  final List<GalleryPhoto> photos;
  final Map<String, String> imageHeaders;
  final ValueChanged<int> onPhotoTap;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final previewCount = photos.length.clamp(1, 4);
    final columns = previewCount == 1 ? 1 : 2;
    final rows = (previewCount / columns).ceil();
    final previewHeight = previewCount == 1 ? 230.0 : rows * 128.0;

    return Padding(
      padding: const EdgeInsets.only(left: 44),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 360),
          tween: Tween(begin: 0, end: 1),
          builder: (context, value, child) => Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 14 * (1 - value)),
              child: child,
            ),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(5),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(18),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 340),
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      scheme.surface.withAlpha(174),
                      scheme.surfaceContainerHighest.withAlpha(126),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(5),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                  ),
                  border: Border.all(
                    color: scheme.outlineVariant.withAlpha(105),
                  ),
                ),
                child: SizedBox(
                  height: previewHeight,
                  child: GridView.builder(
                    padding: EdgeInsets.zero,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisSpacing: 3,
                      crossAxisSpacing: 3,
                      childAspectRatio: previewCount == 1 ? 1.42 : 1.25,
                    ),
                    itemCount: previewCount,
                    itemBuilder: (context, index) {
                      final remaining = photos.length - previewCount;
                      return GestureDetector(
                        onTap: remaining > 0 && index == previewCount - 1
                            ? onViewAll
                            : () => onPhotoTap(index),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CachedNetworkImage(
                                imageUrl: photos[index].thumbnailUrl,
                                httpHeaders: imageHeaders,
                                memCacheWidth:
                                    (180 *
                                            MediaQuery.devicePixelRatioOf(
                                              context,
                                            ))
                                        .round(),
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(
                                  color: scheme.surfaceContainerHigh,
                                ),
                                errorWidget: (_, __, ___) => Container(
                                  color: scheme.surfaceContainerHigh,
                                  child: const Icon(CupertinoIcons.photo),
                                ),
                              ),
                              if (remaining > 0 && index == previewCount - 1)
                                ColoredBox(
                                  color: Colors.black.withAlpha(112),
                                  child: Center(
                                    child: Text(
                                      '+$remaining',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 28,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AssistantMessage extends StatelessWidget {
  final String text;

  const _AssistantMessage({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: primaryColor,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            CupertinoIcons.sparkles,
            color: Colors.white,
            size: 17,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              text,
              style: const TextStyle(fontSize: 15.5, height: 1.35),
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchingReply extends StatelessWidget {
  final Animation<double> animation;

  const _SearchingReply({required this.animation});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        RotationTransition(
          turns: animation,
          child: Icon(CupertinoIcons.sparkles, color: primaryColor, size: 26),
        ),
        const SizedBox(width: 12),
        const Text('Searching your smrutis…', style: TextStyle(fontSize: 16)),
      ],
    );
  }
}

class _PromptComposer extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isListening;
  final bool isSearching;
  final String languageLabel;
  final VoidCallback onLanguage;
  final VoidCallback onMic;
  final VoidCallback onSend;

  const _PromptComposer({
    required this.controller,
    required this.focusNode,
    required this.isListening,
    required this.isSearching,
    required this.languageLabel,
    required this.onLanguage,
    required this.onMic,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            color: scheme.surface.withAlpha(205),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: onLanguage,
                    icon: const Icon(CupertinoIcons.globe, size: 16),
                    label: Text(languageLabel, overflow: TextOverflow.ellipsis),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        focusNode: focusNode,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => onSend(),
                        decoration: InputDecoration(
                          hintText: isListening
                              ? 'Listening…'
                              : 'Ask for any smruti…',
                          filled: true,
                          fillColor: scheme.surfaceContainerHighest,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: onMic,
                      icon: Icon(
                        isListening
                            ? CupertinoIcons.stop_fill
                            : CupertinoIcons.mic_fill,
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton.filled(
                      onPressed: isSearching ? null : onSend,
                      style: IconButton.styleFrom(
                        backgroundColor: primaryColor,
                      ),
                      icon: isSearching
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              CupertinoIcons.arrow_up,
                              color: Colors.white,
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
