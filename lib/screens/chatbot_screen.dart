import 'package:flutter/material.dart';
import 'package:mood_app/services/gemini_service.dart';
import 'package:url_launcher/url_launcher.dart';

class ChatbotScreen extends StatefulWidget {
  final String userName;
  final String emotion;

  const ChatbotScreen({
    super.key,
    required this.userName,
    required this.emotion,
  });

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  _ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late GeminiService _geminiService;
  final List<_ChatMessage> _messages = [];
  
  bool _isLoading = false;
  bool _hasApiKey = false;
  String? _apiKeyError;

  @override
  void initState() {
    super.initState();
    _geminiService = GeminiService(
      userName: widget.userName,
      currentMood: widget.emotion,
    );
    _checkApiKey().then((_) {
      if (!_hasApiKey && mounted) {
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted && !_hasApiKey) _showApiKeyDialog();
        });
      }
    });
    _addInitialGreeting();
  }

  void _addInitialGreeting() {
    String greeting;
    switch (widget.emotion.toLowerCase()) {
      case 'happy':
        greeting = "Hi ${widget.userName}! I'm so happy to hear that you are feeling happy today! 😊 What's making you smile? I'm here to chat about it!";
        break;
      case 'sad':
        greeting = "Hello ${widget.userName}. I see you are feeling a bit down or sad. 💙 Remember, it's completely okay to feel this way. I'm here to listen. Would you like to talk about what's on your mind?";
        break;
      case 'angry':
        greeting = "Hi ${widget.userName}. I detect some anger or frustration. 😠 Take a deep breath. I'm here to help you vent and process what happened. Tell me, what's causing this?";
        break;
      case 'surprise':
        greeting = "Hey ${widget.userName}! Sounds like you had a surprise! 😲 Was it a good one? Tell me all about it, I'd love to hear!";
        break;
      case 'fear':
        greeting = "Hello ${widget.userName}. I feel you might be anxious or fearful right now. 😟 You are safe here. Let's take it slow. What is causing you worry?";
        break;
      case 'disgust':
        greeting = "Hi ${widget.userName}. Feeling disgusted or uncomfortable? 🤢 That's a strong emotion. Want to share what's bothering you?";
        break;
      case 'contempt':
        greeting = "Hello ${widget.userName}. Feeling a bit of contempt or resentment? Let's chat and unpack these feelings together. I'm here for you.";
        break;
      case 'neutral':
      default:
        greeting = "Hello ${widget.userName}. Feeling neutral today? That's a peaceful state of mind. 🌸 How has your day been so far? Anything you'd like to share?";
        break;
    }
    
    _messages.add(_ChatMessage(
      text: greeting,
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }

  Future<void> _checkApiKey() async {
    final apiKey = await GeminiService.getApiKey();
    setState(() {
      _hasApiKey = apiKey != null && apiKey.isNotEmpty;
    });
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

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    if (!_hasApiKey) {
      _showApiKeyDialog();
      return;
    }

    _messageController.clear();
    setState(() {
      _messages.add(_ChatMessage(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
      _apiKeyError = null;
    });
    _scrollToBottom();

    try {
      final aiResponse = await _geminiService.sendMessage(text);
      setState(() {
        _messages.add(_ChatMessage(
          text: aiResponse,
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _apiKeyError = e.toString().replaceFirst('Exception: ', '');
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${_apiKeyError ?? "Failed to get response"}'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _openApiKeyPage() async {
    final uri = Uri.parse('https://aistudio.google.com/apikey');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Google AI Studio')),
      );
    }
  }

  void _showApiKeyDialog() {
    final TextEditingController keyController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Gemini API Key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'الشات بوت محتاج Gemini API Key مجاني من Google.\n'
              '1) اضغط Get Free Key\n'
              '2) انسخ المفتاح\n'
              '3) الصقه هنا واضغط Save\n\n'
              'المفتاح يُحفظ في التخزين الآمن على جهازك. لكن لأن التطبيق يتصل '
              'مباشرةً بـ Gemini، يمكن استخراج المفتاح من نسخة التطبيق؛ لا تستخدم '
              'مفتاحًا حساسًا أو إنتاجيًا. للاستخدام الإنتاجي، مرّر الطلبات عبر خادم آمن.',
              style: TextStyle(fontSize: 13, color: Colors.black87, height: 1.4),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _openApiKeyPage,
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Get Free Key'),
              style: TextButton.styleFrom(
                foregroundColor: _getThemeColor(widget.emotion),
                padding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: keyController,
              obscureText: true,
              decoration: InputDecoration(
                hintText: 'AIzaSy...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _getThemeColor(widget.emotion),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              final key = keyController.text.trim();
              if (key.isNotEmpty) {
                await GeminiService.saveApiKey(key);
                await _checkApiKey();
                if (mounted) Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Gemini API Key saved successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child:
                const Text('Save Key', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = _getThemeColor(widget.emotion);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'YouMatter AI Companion',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
            ),
            Text(
              'Tailored to your ${widget.emotion} mood',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        backgroundColor: themeColor,
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(
              _hasApiKey ? Icons.vpn_key : Icons.vpn_key_outlined,
              color: _hasApiKey ? Colors.greenAccent : Colors.white70,
            ),
            tooltip: 'Configure API Key',
            onPressed: _showApiKeyDialog,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              themeColor.withOpacity(0.05),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              if (!_hasApiKey)
                Container(
                  color: Colors.amber.shade100,
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Gemini API Key is not set. Tap key icon above to set.',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                      ),
                      TextButton(
                        onPressed: _showApiKeyDialog,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('SETUP', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    return _buildChatBubble(msg, themeColor);
                  },
                ),
              ),
              if (_isLoading)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'YouMatter AI is thinking...',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              _buildInputArea(themeColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatBubble(_ChatMessage message, Color themeColor) {
    final align = message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bubbleColor = message.isUser ? themeColor : Colors.grey.shade100;
    final isDarkThemeColor = ThemeData.estimateBrightnessForColor(themeColor) == Brightness.dark;
    final textColor = message.isUser
        ? (isDarkThemeColor ? Colors.white : Colors.black87)
        : Colors.black87;
    
    final radius = message.isUser
        ? const BorderRadius.only(
            topLeft: Radius.circular(20),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          )
        : const BorderRadius.only(
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: align,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: radius,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              message.text,
              style: TextStyle(
                color: textColor,
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _formatTime(message.timestamp),
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Widget _buildInputArea(Color themeColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(25),
              ),
              child: TextField(
                controller: _messageController,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _sendMessage(),
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: themeColor,
            radius: 24,
            child: IconButton(
              icon: const Icon(Icons.send_rounded, color: Colors.white),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}
