import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/track.dart';
import '../services/ai_studio_service.dart';
import '../services/ai_music_service.dart';
import '../services/settings_service.dart';
import 'app_alert.dart';

class SongAiStudioSheet extends StatefulWidget {
  final Track track;

  const SongAiStudioSheet({
    super.key,
    required this.track,
  });

  @override
  State<SongAiStudioSheet> createState() => _SongAiStudioSheetState();
}

class _SongAiStudioSheetState extends State<SongAiStudioSheet> {
  final TextEditingController _queryCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  SongAiAnalysis? _analysis;
  bool _isLoading = true;
  int _activeTab = 0; // 0: Taste & DNA, 1: Studio & Chords, 2: AI Chat & Mix

  final List<String> _quickQueries = [
    'What instruments are used?',
    'What are the chords?',
    'Explain lyrics & story',
    'How was this produced?',
    'DAW recreation tips',
  ];

  @override
  void initState() {
    super.initState();
    _loadAnalysis();
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAnalysis() async {
    final res = await AiStudioService.instance.analyzeTrack(widget.track);
    if (mounted) {
      setState(() {
        _analysis = res;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleAsk(String question) async {
    final clean = question.trim();
    if (clean.isEmpty) return;
    _queryCtrl.clear();

    await AiStudioService.instance.askSongQuestion(widget.track, clean);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _generateMatchingPlaylist() async {
    Navigator.pop(context);
    AppAlert.show(
      context,
      'Synthesizing AI Playlist based on "${widget.track.title}"...',
      icon: Icons.auto_awesome,
    );

    final prompt = '${widget.track.title} ${widget.track.genre} ${widget.track.mood} instruments';
    final playlist = await AiMusicService.instance.generatePlaylistFromPrompt(prompt);

    if (mounted) {
      AppAlert.show(
        context,
        'Created "${playlist.title}" with ${playlist.tracks.length} tracks!',
        icon: Icons.check_circle_rounded,
        isSuccess: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = SettingsService.instance.accentColor;
    final hasGeminiKey = SettingsService.instance.geminiApiKey.isNotEmpty;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFF0F0F12),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: accent.withValues(alpha: 0.3)),
                  ),
                  child: Icon(Icons.auto_awesome_rounded, color: accent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'AI Acoustic Studio',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: hasGeminiKey
                                  ? const Color(0xFF10B981).withValues(alpha: 0.2)
                                  : accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: hasGeminiKey ? const Color(0xFF10B981) : accent.withValues(alpha: 0.4),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              hasGeminiKey ? 'Gemini 1.5' : 'Neural AI',
                              style: TextStyle(
                                color: hasGeminiKey ? const Color(0xFF34D399) : accent,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.track.title} • ${widget.track.artist}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Clean Spotify-Style Segmented Pill Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              children: [
                _buildTabPill('Taste & DNA', 0, Icons.insights_rounded, accent),
                const SizedBox(width: 8),
                _buildTabPill('Studio & Chords', 1, Icons.music_note_rounded, accent),
                const SizedBox(width: 8),
                _buildTabPill('AI Chat & Mix', 2, Icons.forum_rounded, accent),
              ],
            ),
          ),

          const Divider(color: Color(0xFF222228), height: 1),

          // Main Tab Content
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        SizedBox(height: 16),
                        Text(
                          'Deconstructing sonic frequencies & instruments...',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : _buildActiveTabContent(accent),
          ),

          // Bottom Query Input Bar (Active on Tab 2)
          if (_activeTab == 2)
            Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 10,
                bottom: MediaQuery.of(context).viewInsets.bottom + 12,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF14141A),
                border: Border(top: BorderSide(color: Color(0xFF22222E))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E26),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFF2E2E3C)),
                      ),
                      child: TextField(
                        controller: _queryCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: const InputDecoration(
                          hintText: 'Ask AI about instruments, chords, theory...',
                          hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: InputBorder.none,
                        ),
                        onSubmitted: _handleAsk,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: accent,
                      shape: const CircleBorder(),
                    ),
                    icon: const Icon(Icons.arrow_upward_rounded, color: Colors.black, size: 20),
                    onPressed: () => _handleAsk(_queryCtrl.text),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTabPill(String title, int index, IconData icon, Color accent) {
    final isSelected = _activeTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            _activeTab = index;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? accent : const Color(0xFF1A1A20),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? accent : const Color(0xFF2A2A34),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 13,
                color: isSelected ? Colors.black : Colors.white70,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.white70,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveTabContent(Color accent) {
    switch (_activeTab) {
      case 0:
        return _buildTasteAndDnaTab(accent);
      case 1:
        return _buildStudioAndChordsTab(accent);
      case 2:
      default:
        return _buildAiChatAndMixTab(accent);
    }
  }

  // --- TAB 0: Taste & DNA ---
  Widget _buildTasteAndDnaTab(Color accent) {
    final taste = AiMusicService.instance.explainRecommendation(widget.track);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Match Score Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF16161D),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF272733)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: accent.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      '${(taste.matchPercentage * 100).toInt()}% Taste Profile Match',
                      style: TextStyle(
                        color: accent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    widget.track.mood.isNotEmpty ? widget.track.mood : 'Curated',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                taste.primaryReason,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Musical DNA & Tonality Card
        _buildMusicalDnaCard(accent),

        const SizedBox(height: 16),

        // Acoustic Feature Compatibility Bars
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF16161D),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF272733)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.tune_rounded, color: Colors.white70, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Acoustic Compatibility Vectors',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ...taste.acousticMatches.entries.map((entry) {
                final pct = (entry.value * 100).toInt();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(entry.key, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          Text(
                            '$pct%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: entry.value,
                          backgroundColor: Colors.white10,
                          valueColor: AlwaysStoppedAnimation<Color>(accent),
                          minHeight: 5,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Detailed Reasoning Bullets
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF16161D),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF272733)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Key Neural Factors',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              ...taste.detailedReasons.map((bullet) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.check_circle_outline_rounded, color: accent, size: 15),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            bullet,
                            style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Smart Mix Button
        OutlinedButton.icon(
          onPressed: _generateMatchingPlaylist,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: BorderSide(color: accent.withValues(alpha: 0.5)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            backgroundColor: accent.withValues(alpha: 0.08),
          ),
          icon: Icon(Icons.auto_awesome, color: accent, size: 18),
          label: Text(
            'Synthesize AI Smart Mix With This Vibe',
            style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),

        const SizedBox(height: 20),
      ],
    );
  }

  // --- TAB 1: Studio & Chords ---
  Widget _buildStudioAndChordsTab(Color accent) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildInstrumentsSection(accent),
        const SizedBox(height: 16),
        _buildChordCard(accent),
        const SizedBox(height: 16),
        _buildStoryCard(),
        const SizedBox(height: 16),
        _buildProductionNotesCard(),
        const SizedBox(height: 20),
      ],
    );
  }

  // --- TAB 2: AI Chat & Mix ---
  Widget _buildAiChatAndMixTab(Color accent) {
    return ListView(
      controller: _scrollCtrl,
      padding: const EdgeInsets.all(20),
      children: [
        // Action Button: Synthesize AI Playlist
        OutlinedButton.icon(
          onPressed: _generateMatchingPlaylist,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: BorderSide(color: accent.withValues(alpha: 0.5)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            backgroundColor: accent.withValues(alpha: 0.08),
          ),
          icon: Icon(Icons.auto_awesome, color: accent, size: 18),
          label: Text(
            'Synthesize AI Playlist From This Sonic DNA',
            style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),

        const SizedBox(height: 20),

        const Row(
          children: [
            Icon(Icons.forum_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text(
              'Ask AI Studio About This Track',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Quick Questions Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _quickQueries.map((q) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  label: Text(q, style: const TextStyle(fontSize: 12, color: Colors.white)),
                  backgroundColor: const Color(0xFF1E1E24),
                  side: const BorderSide(color: Color(0xFF33333F)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  onPressed: () => _handleAsk(q),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 14),

        // Chat messages stream
        ListenableBuilder(
          listenable: AiStudioService.instance,
          builder: (context, _) {
            final history = AiStudioService.instance.chatHistory;
            if (history.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF18181F),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF262633)),
                ),
                child: const Text(
                  'Tap any question above or type anything about instruments, chord voicings, meaning, or production techniques!',
                  style: TextStyle(color: Colors.white60, fontSize: 13),
                ),
              );
            }

            return Column(
              children: history.map((msg) {
                final isUser = msg.sender == 'user';
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.82,
                    ),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser ? accent.withValues(alpha: 0.2) : const Color(0xFF1E1E26),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isUser ? accent.withValues(alpha: 0.4) : const Color(0xFF2E2E3A),
                      ),
                    ),
                    child: Text(
                      msg.text,
                      style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildMusicalDnaCard(Color accent) {
    if (_analysis == null) return const SizedBox.shrink();
    final a = _analysis!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16161D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF272733)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Musical DNA & Tonality',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                '${a.bpm} BPM',
                style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildDnaPill('Key', a.musicalKey, Icons.music_note_rounded),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDnaPill('Scale', a.scaleMode, Icons.waves_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildDnaPill('Tuning', a.tuning, Icons.tune_rounded),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDnaPill('Meter', a.timeSignature, Icons.timer_outlined),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDnaPill(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E28),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2C2C3A)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstrumentsSection(Color accent) {
    if (_analysis == null) return const SizedBox.shrink();
    final instruments = _analysis!.instruments;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16161D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF272733)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.piano_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Instruments Identified in Audio',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${instruments.length} Tracked',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Column(
            children: instruments.map((inst) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C26),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2A2A38)),
                ),
                child: Row(
                  children: [
                    _getInstrumentCategoryIcon(inst.category, accent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                inst.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${(inst.prominence * 100).toInt()}% Mix',
                                style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          if (inst.description.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              inst.description,
                              style: const TextStyle(color: Colors.white60, fontSize: 11),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _getInstrumentCategoryIcon(String category, Color accent) {
    IconData icon = Icons.music_note_rounded;
    switch (category.toLowerCase()) {
      case 'string':
        icon = Icons.album_rounded;
        break;
      case 'keys':
        icon = Icons.piano_rounded;
        break;
      case 'synth':
        icon = Icons.memory_rounded;
        break;
      case 'percussion':
        icon = Icons.adjust_rounded;
        break;
      case 'bass':
        icon = Icons.speaker_rounded;
        break;
      case 'vocal':
        icon = Icons.mic_rounded;
        break;
    }
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: accent, size: 18),
    );
  }

  Widget _buildStoryCard() {
    if (_analysis == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16161D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF272733)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_stories_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text(
                'Lyrical Story & Meaning',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _analysis!.storyAndMeaning,
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _buildChordCard(Color accent) {
    if (_analysis == null) return const SizedBox.shrink();
    final chords = _analysis!.chordProgression;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16161D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF272733)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.grid_view_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text(
                'Core Harmonic Chords',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: chords.map((chord) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF21212B),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: accent.withValues(alpha: 0.3)),
                ),
                child: Text(
                  chord,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildProductionNotesCard() {
    if (_analysis == null) return const SizedBox.shrink();
    final notes = _analysis!.productionNotes;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16161D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF272733)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.precision_manufacturing_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text(
                'Studio Production & Mixing Notes',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Column(
            children: notes.map((note) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    Expanded(
                      child: Text(
                        note,
                        style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.35),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
