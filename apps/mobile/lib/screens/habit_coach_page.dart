import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:dio/dio.dart';
import '../services/api_service.dart';
import '../constants/colors.dart';

// ─── Model ────────────────────────────────────────────────────────────────────

enum CoachMode {
  quickCheckin('quick_checkin', 'Quick Check-in'),
  deepCoaching('deep_coaching', 'Deep Coaching'),
  goalSetup('goal_setup', 'Goal Setup'),
  recovery('recovery', 'Recovery'),
  weeklyReview('weekly_review', 'Weekly Review'),
  celebration('celebration', 'Celebration');

  const CoachMode(this.value, this.label);
  final String value;
  final String label;
}

class ChatMessage {
  final String content;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.content,
    required this.isUser,
    required this.timestamp,
  });
}

// ─── State ────────────────────────────────────────────────────────────────────

class CoachState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final CoachMode mode;
  final String? error;
  final String? sessionId;

  CoachState({
    this.messages = const [],
    this.isLoading = false,
    this.mode = CoachMode.quickCheckin,
    this.error,
    this.sessionId,
  });

  CoachState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    CoachMode? mode,
    String? error,
    String? sessionId,
  }) =>
      CoachState(
        messages: messages ?? this.messages,
        isLoading: isLoading ?? this.isLoading,
        mode: mode ?? this.mode,
        error: error ?? this.error,
        sessionId: sessionId ?? this.sessionId,
      );
}

class CoachNotifier extends StateNotifier<CoachState> {
  final Dio _dio;

  CoachNotifier({required Dio dio})
      : _dio = dio,
        super(CoachState());

  Future<void> initMode() async {
    try {
      final res = await _dio.get('/coach/mode-hint');
      final modeVal = res.data['mode'] as String;
      final mode = CoachMode.values.firstWhere(
        (m) => m.value == modeVal,
        orElse: () => CoachMode.quickCheckin,
      );
      state = state.copyWith(mode: mode);
    } catch (_) {}
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final userMsg = ChatMessage(
      content: text.trim(),
      isUser: true,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isLoading: true,
      error: null,
    );

    try {
      final res = await _dio.post(
        '/coach/chat',
        data: jsonEncode({
          'mode': state.mode.value,
          'message': text.trim(),
          if (state.sessionId != null) 'sessionId': state.sessionId,
        }),
      );

      final reply = res.data['reply'] as String;
      final newSessionId = res.data['sessionId'] as String?;
      final assistantMsg = ChatMessage(
        content: reply,
        isUser: false,
        timestamp: DateTime.now(),
      );

      state = state.copyWith(
        messages: [...state.messages, assistantMsg],
        isLoading: false,
        sessionId: newSessionId,
      );
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.response?.data?['error'] ?? 'Something went wrong',
      );
    }
  }

  void setMode(CoachMode mode) {
    state = state.copyWith(mode: mode, messages: [], error: null);
  }

  void clearError() => state = state.copyWith(error: null);
}

// ─── Providers ────────────────────────────────────────────────────────────────

final dioProvider = Provider<Dio>((ref) => ApiService().dio);

final coachProvider =
    StateNotifierProvider<CoachNotifier, CoachState>((ref) {
  return CoachNotifier(
    dio: ref.watch(dioProvider),
  );
});

// ─── Page ─────────────────────────────────────────────────────────────────────

class HabitCoachPage extends ConsumerStatefulWidget {
  HabitCoachPage({super.key});

  @override
  ConsumerState<HabitCoachPage> createState() => _HabitCoachPageState();
}

class _HabitCoachPageState extends ConsumerState<HabitCoachPage>
    with TickerProviderStateMixin {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late AnimationController _pulseController;

  Color get _primaryColor => Theme.of(context).colorScheme.primary;
  Color get _surfaceColor => AppColors.scaffoldBackground;
  Color get _cardColor => Theme.of(context).colorScheme.surface;
  Color get _accentColor => Theme.of(context).colorScheme.tertiary;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(coachProvider.notifier).initMode();
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _send() {
    final text = _inputController.text;
    _inputController.clear();
    ref.read(coachProvider.notifier).sendMessage(text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(coachProvider);

    ref.listen<CoachState>(coachProvider, (_, next) {
      if (next.messages.isNotEmpty) _scrollToBottom();
    });

    return Scaffold(
      backgroundColor: _surfaceColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(state),
            _buildModeBar(state),
            if (state.error != null) _buildErrorBanner(state.error!),
            Expanded(
              child: state.messages.isEmpty
                  ? _buildEmptyState(state.mode)
                  : _buildMessageList(state),
            ),
            _buildInputBar(state),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(CoachState state) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: BoxDecoration(
        color: _cardColor,
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.15),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 12),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(14),
              boxShadow: AppColors.softShadow,
            ),
            child: const Icon(Icons.psychology_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Habit Coach',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      state.mode.label,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.tune_rounded,
                color: AppColors.textSecondary, size: 22),
            onPressed: () => _showModeSheet(context),
          ),
        ],
      ),
    );
  }

  Widget _buildModeBar(CoachState state) {
    final quickModes = [
      CoachMode.quickCheckin,
      CoachMode.deepCoaching,
      CoachMode.goalSetup,
      CoachMode.weeklyReview,
    ];

    return Container(
      height: 44,
      color: _cardColor,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: quickModes.length,
        separatorBuilder: (_, __) => SizedBox(width: 8),
        itemBuilder: (_, i) {
          final m = quickModes[i];
          final isSelected = m == state.mode;
          return GestureDetector(
            onTap: () => ref.read(coachProvider.notifier).setMode(m),
            child: AnimatedContainer(
              duration: Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isSelected
                    ? _primaryColor
                    : _accentColor.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? _primaryColor
                      : AppColors.primary.withOpacity(0.06),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                m.label,
                style: TextStyle(
                  color: isSelected
                      ? AppColors.textPrimary
                      : AppColors.textPrimary.withOpacity(0.55),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(CoachMode mode) {
    final prompts = _suggestedPrompts(mode);
    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        children: [
          SizedBox(height: 24),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              boxShadow: AppColors.softShadow,
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                color: AppColors.primary, size: 36),
          ),
          SizedBox(height: 20),
          Text(
            _modeGreeting(mode),
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            _modeSubtitle(mode),
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 32),
          ...prompts.map((p) => _buildSuggestedPrompt(p)),
        ],
      ),
    );
  }

  Widget _buildSuggestedPrompt(String prompt) {
    return GestureDetector(
      onTap: () {
        _inputController.text = prompt;
        _send();
      },
      child: Container(
        width: double.infinity,
        margin: EdgeInsets.only(bottom: 10),
        padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withOpacity(0.06)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                prompt,
                style: TextStyle(
                  color: AppColors.textPrimary.withOpacity(0.75),
                  fontSize: 14,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_rounded,
                color: _primaryColor.withOpacity(0.7), size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList(CoachState state) {
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: state.messages.length + (state.isLoading ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == state.messages.length) return _buildTypingIndicator();
        return _buildMessageBubble(state.messages[i]);
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        margin: EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: msg.isUser ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(24),
            topRight: const Radius.circular(24),
            bottomLeft: Radius.circular(msg.isUser ? 24 : 6),
            bottomRight: Radius.circular(msg.isUser ? 6 : 24),
          ),
          boxShadow: AppColors.softShadow,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: msg.isUser
            ? Text(
                msg.content,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              )
            : MarkdownBody(
                data: msg.content,
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(
                    color: AppColors.textPrimary.withOpacity(0.88),
                    fontSize: 15,
                    height: 1.5,
                  ),
                  strong: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                  listBullet: TextStyle(
                    color: _primaryColor.withOpacity(0.8),
                  ),
                  h3: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomRight: Radius.circular(20),
            bottomLeft: Radius.circular(4),
          ),
          border: Border.all(color: AppColors.textPrimary.withOpacity(0.07)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            return AnimatedBuilder(
              animation: _pulseController,
              builder: (_, __) {
                final delay = i * 0.3;
                final t = (_pulseController.value - delay).clamp(0.0, 1.0);
                return Container(
                  margin: EdgeInsets.only(right: i < 2 ? 5 : 0),
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: _primaryColor.withValues(alpha: 0.4 + 0.6 * t),
                    shape: BoxShape.circle,
                  ),
                );
              },
            );
          }),
        ),
      ),
    );
  }

  Widget _buildInputBar(CoachState state) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: _cardColor,
        border: Border(
          top: BorderSide(color: AppColors.textPrimary.withOpacity(0.07)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: 'Message your coach…',
                hintStyle: TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 15,
                ),
                filled: true,
                fillColor: _accentColor.withOpacity(0.5),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(
                    color: _primaryColor.withOpacity(0.5),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 10),
          GestureDetector(
            onTap: state.isLoading ? null : _send,
            child: AnimatedContainer(
              duration: Duration(milliseconds: 200),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: state.isLoading ? AppColors.textTertiary : AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: state.isLoading ? null : AppColors.softShadow,
              ),
              child: Icon(
                state.isLoading ? Icons.hourglass_top_rounded : Icons.send_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String error) {
    return Container(
      margin: EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
          ),
          GestureDetector(
            onTap: () => ref.read(coachProvider.notifier).clearError(),
            child: Icon(Icons.close_rounded, color: Colors.redAccent, size: 18),
          ),
        ],
      ),
    );
  }

  void _showModeSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Consumer(
        builder: (ctx, ref, __) {
          final currentMode = ref.watch(coachProvider).mode;
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  'Switch Mode',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 16),
                ...CoachMode.values.map((m) {
                  final isSelected = m == currentMode;
                  return ListTile(
                    onTap: () {
                      ref.read(coachProvider.notifier).setMode(m);
                      Navigator.pop(ctx);
                    },
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? _primaryColor.withOpacity(0.2)
                            : _accentColor.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _modeIcon(m),
                        color: isSelected ? _primaryColor : AppColors.textPrimary.withOpacity(0.38),
                        size: 20,
                      ),
                    ),
                    title: Text(
                      m.label,
                      style: TextStyle(
                        color: isSelected ? AppColors.textPrimary : AppColors.textPrimary.withOpacity(0.87),
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      _modeSubtitle(m),
                      style: TextStyle(
                        color: AppColors.textPrimary.withOpacity(0.35),
                        fontSize: 12,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check_circle_rounded,
                            color: _primaryColor, size: 20)
                        : null,
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  IconData _modeIcon(CoachMode mode) => switch (mode) {
        CoachMode.quickCheckin => Icons.wb_sunny_rounded,
        CoachMode.deepCoaching => Icons.psychology_rounded,
        CoachMode.goalSetup => Icons.flag_rounded,
        CoachMode.recovery => Icons.favorite_rounded,
        CoachMode.weeklyReview => Icons.bar_chart_rounded,
        CoachMode.celebration => Icons.celebration_rounded,
      };

  String _modeGreeting(CoachMode mode) => switch (mode) {
        CoachMode.quickCheckin => "How's your day going? 👋",
        CoachMode.deepCoaching => "Ready to go deep?",
        CoachMode.goalSetup => "Let's build something meaningful 🎯",
        CoachMode.recovery => "Welcome back. No pressure here.",
        CoachMode.weeklyReview => "Time to reflect on your week 📊",
        CoachMode.celebration => "You did something worth celebrating 🔥",
      };

  String _modeSubtitle(CoachMode mode) => switch (mode) {
        CoachMode.quickCheckin => "Quick daily check-in",
        CoachMode.deepCoaching => "Full coaching session",
        CoachMode.goalSetup => "Define and break down a new goal",
        CoachMode.recovery => "Get back on track gently",
        CoachMode.weeklyReview => "Review progress, plan ahead",
        CoachMode.celebration => "Acknowledge a milestone",
      };

  List<String> _suggestedPrompts(CoachMode mode) => switch (mode) {
        CoachMode.quickCheckin => [
            "I completed my morning routine today ✅",
            "I missed my habit yesterday, what should I do?",
            "How am I doing overall this week?",
          ],
        CoachMode.deepCoaching => [
            "I'm struggling to stay consistent — help me figure out why",
            "Let's audit my current habits and see what's working",
            "I want to redesign my morning routine",
          ],
        CoachMode.goalSetup => [
            "I want to start running 5K in 3 months",
            "Help me build a reading habit — 20 books this year",
            "I want to learn a new skill consistently",
          ],
        CoachMode.recovery => [
            "I fell off track for 2 weeks. Where do I start?",
            "I feel overwhelmed and don't know which habit to focus on",
            "Can we simplify everything and start small?",
          ],
        CoachMode.weeklyReview => [
            "Let's do my weekly review",
            "What patterns do you see in my last 7 days?",
            "Help me plan next week's focus areas",
          ],
        CoachMode.celebration => [
            "I just hit a 30-day streak! 🔥",
            "I completed my goal this month",
            "I finally stuck to a habit I've been trying to build for months",
          ],
      };
}

