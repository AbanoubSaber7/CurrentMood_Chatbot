import 'package:flutter/material.dart';
import 'package:mood_app/widgets/background_widget.dart';
import 'package:mood_app/screens/playlists_screen.dart';
import 'package:mood_app/screens/videos_screen.dart';
import 'package:mood_app/screens/stories_screen.dart';
import 'package:mood_app/screens/activities_screen.dart';
import 'package:mood_app/screens/chatbot_screen.dart';
import 'package:mood_app/models/mood_history_entry.dart';
import 'package:mood_app/services/mood_history_service.dart';

class RecommendationsScreen extends StatefulWidget {
  final String userName;
  final String emotion;
  final double? confidencePercent;
  final String source;

  const RecommendationsScreen({
    super.key,
    required this.userName,
    required this.emotion,
    this.confidencePercent,
    this.source = 'model',
  });

  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen>
    with SingleTickerProviderStateMixin {
  static const double _lowConfidenceThreshold = 40.0;
  static const List<String> _emotionLabels = [
    'Neutral',
    'Happy',
    'Surprise',
    'Sad',
    'Angry',
    'Disgust',
    'Fear',
    'Contempt',
  ];

  final _history = MoodHistoryService();
  late String _selectedEmotion;
  late bool _confirmed;
  bool _saved = false;

  late final AnimationController _chatAnimController;
  late final Animation<double> _chatScaleAnimation;
  late final Animation<double> _chatHaloScaleAnimation;
  late final Animation<double> _chatHaloOpacityAnimation;

  @override
  void initState() {
    super.initState();
    _chatAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _chatScaleAnimation = Tween<double>(begin: 0.98, end: 1.04).animate(
      CurvedAnimation(parent: _chatAnimController, curve: Curves.easeInOut),
    );
    _chatHaloScaleAnimation = Tween<double>(begin: 1.0, end: 1.45).animate(
      CurvedAnimation(parent: _chatAnimController, curve: Curves.easeOut),
    );
    _chatHaloOpacityAnimation = Tween<double>(begin: 0.4, end: 0).animate(
      CurvedAnimation(parent: _chatAnimController, curve: Curves.easeOut),
    );
    _selectedEmotion = widget.emotion;
    final conf = widget.confidencePercent;
    _confirmed =
        conf == null ||
        conf >= _lowConfidenceThreshold ||
        widget.source != 'model';
    if (_confirmed) {
      _saveHistoryIfNeeded(
        finalEmotion: _selectedEmotion,
        predictedEmotion: widget.source == 'model' ? widget.emotion : null,
      );
    }
  }

  @override
  void dispose() {
    _chatAnimController.stop();
    _chatAnimController.dispose();
    super.dispose();
  }

  Color _getThemeColor(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'happy':
        return Colors.amber.shade700;
      case 'sad':
        return Colors.blueGrey;
      case 'angry':
        return Colors.redAccent;
      case 'surprise':
        return Colors.orangeAccent;
      case 'fear':
        return Colors.deepPurple;
      case 'contempt':
        return Colors.blueGrey.shade800;
      case 'disgust':
        return const Color.fromARGB(255, 174, 79, 146);
      case 'neutral':
      default:
        return const Color(0xFFC05A4E);
    }
  }

  Future<void> _saveHistoryIfNeeded({
    required String finalEmotion,
    String? predictedEmotion,
  }) async {
    if (_saved) return;
    _saved = true;
    await _history.addEntry(
      MoodHistoryEntry(
        emotion: finalEmotion,
        confidencePercent: widget.confidencePercent,
        timestamp: DateTime.now(),
        source: widget.source,
        predictedEmotion: predictedEmotion,
      ),
      maxEntries: 20,
    );
  }

  String _getQuote(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'sad':
        return "Every cloud has a silver lining.";
      case 'angry':
        return "Speak when you are angry and you will make the best speech you will ever regret.";
      case 'happy':
        return "Happiness is not something ready made. It comes from your own actions.";
      case 'fear':
        return "Do one thing every day that scares you.";
      case 'neutral':
        return "Peace is its own reward.";
      case 'contempt':
        return "Be the best version of yourself, always.";
      default:
        return "Believe in yourself and all that you are.";
    }
  }

  Widget _buildCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color themeColor,
    required Widget targetScreen,
  }) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => targetScreen),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: themeColor.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: themeColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: themeColor, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                color: themeColor.withAlpha(200),
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  void _openChatbot(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatbotScreen(
          userName: widget.userName,
          emotion: _confirmed ? _selectedEmotion : 'Neutral',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final conf = widget.confidencePercent;
    final showConfirm =
        widget.source == 'model' &&
        conf != null &&
        conf < _lowConfidenceThreshold &&
        !_confirmed;
    final effectiveEmotion = _confirmed ? _selectedEmotion : 'Neutral';
    final themeColor = _getThemeColor(effectiveEmotion);
    final isDarkThemeColor =
        ThemeData.estimateBrightnessForColor(themeColor) == Brightness.dark;
    final foregroundColor = isDarkThemeColor
        ? Colors.white
        : const Color(0xFF2D2D2D);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Recommendations',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: themeColor,
        elevation: 0,
        centerTitle: true,
      ),
      floatingActionButton: ScaleTransition(
        scale: _chatScaleAnimation,
        child: SizedBox(
          width: 72,
          height: 72,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              FadeTransition(
                opacity: _chatHaloOpacityAnimation,
                child: ScaleTransition(
                  scale: _chatHaloScaleAnimation,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: themeColor.withOpacity(0.45),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                elevation: 12,
                shadowColor: themeColor.withOpacity(0.45),
                child: Ink(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        themeColor,
                        Color.lerp(
                          themeColor,
                          const Color(0xFF7657E8),
                          0.7,
                        )!,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: InkWell(
                    onTap: () => _openChatbot(context),
                    customBorder: const CircleBorder(),
                    child: Tooltip(
                      message: 'Talk to MoodMate',
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Icon(
                            Icons.chat_bubble_rounded,
                            color: Colors.white,
                            size: 27,
                          ),
                          Positioned(
                            top: 12,
                            right: 15,
                            child: Icon(
                              Icons.auto_awesome_rounded,
                              color: Colors.amber.shade200,
                              size: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: BackgroundWidget(
        emotion: effectiveEmotion,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 30),
                Text(
                  'Hello, ${widget.userName}!',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: foregroundColor,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isDarkThemeColor
                        ? Colors.black.withOpacity(0.45)
                        : themeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: themeColor.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        color: isDarkThemeColor ? Colors.white : themeColor,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Feeling ${effectiveEmotion.toUpperCase()}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDarkThemeColor ? Colors.white : themeColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 25),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDarkThemeColor
                        ? Colors.black.withOpacity(0.45)
                        : themeColor.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border(
                      left: BorderSide(color: themeColor, width: 5),
                    ),
                  ),
                  child: Text(
                    _getQuote(effectiveEmotion),
                    style: TextStyle(
                      fontSize: 15,
                      color: isDarkThemeColor
                          ? Colors.white
                          : Colors.black87.withOpacity(0.7),
                      fontStyle: FontStyle.italic,
                      height: 1.5,
                    ),
                  ),
                ),
                if (showConfirm) ...[
                  const SizedBox(height: 25),
                  _buildConfirmBox(themeColor),
                ],
                const SizedBox(height: 25),
                _buildChatbotBanner(context, themeColor, isDarkThemeColor),
                const SizedBox(height: 35),
                Text(
                  'Recommended for you',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: foregroundColor,
                  ),
                ),
                const SizedBox(height: 20),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                  childAspectRatio: 0.9,
                  children: [
                    _buildCard(
                      context: context,
                      title: 'Music',
                      subtitle: 'Best beats for your mood',
                      icon: Icons.music_note_rounded,
                      themeColor: themeColor,
                      targetScreen: PlaylistsScreen(emotion: effectiveEmotion),
                    ),
                    _buildCard(
                      context: context,
                      title: 'Videos',
                      subtitle: 'Visuals to inspire you',
                      icon: Icons.play_circle_rounded,
                      themeColor: themeColor,
                      targetScreen: VideosScreen(emotion: effectiveEmotion),
                    ),
                    _buildCard(
                      context: context,
                      title: 'Stories',
                      subtitle: 'Escape into words',
                      icon: Icons.menu_book_rounded,
                      themeColor: themeColor,
                      targetScreen: StoriesScreen(emotion: effectiveEmotion),
                    ),
                    _buildCard(
                      context: context,
                      title: 'Activities',
                      subtitle: 'Actionable wellness',
                      icon: Icons.fitness_center_rounded,
                      themeColor: themeColor,
                      targetScreen: ActivitiesScreen(emotion: effectiveEmotion),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmBox(Color themeColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Is this accurate?',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 15),
          DropdownButtonFormField<String>(
            initialValue: _selectedEmotion,
            items: _emotionLabels
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (v) => setState(() => _selectedEmotion = v!),
          ),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: themeColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () async {
                setState(() => _confirmed = true);
                await _saveHistoryIfNeeded(
                  finalEmotion: _selectedEmotion,
                  predictedEmotion: widget.emotion,
                );
              },
              child: const Text(
                'Confirm',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatbotBanner(BuildContext context, Color themeColor, bool isDarkThemeColor) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            themeColor,
            themeColor.withOpacity(0.75),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: themeColor.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => _openChatbot(context),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Colors.white24, Colors.white10],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: Colors.white30),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(
                        Icons.chat_bubble_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                      Positioned(
                        top: -5,
                        right: -5,
                        child: Icon(
                          Icons.auto_awesome_rounded,
                          color: Colors.amber.shade200,
                          size: 15,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Talk to YouMatter AI',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Feeling ${_confirmed ? _selectedEmotion : 'Neutral'}? Let\'s chat about it and process together.',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
