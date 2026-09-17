import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class GeminiService {
  static const String _apiKeyKey = 'gemini_api_key';

  /// Optional compile-time key:
  /// flutter run --dart-define=GEMINI_API_KEY=your_key_here
  static const String _envApiKey = String.fromEnvironment('GEMINI_API_KEY');

  /// Fallback hardcoded key (leave empty in git; set locally if you want).
  static const String defaultApiKey = '';

  /// Current Gemini models (tried in order if one is unavailable).
  static const List<String> _modelCandidates = [
    'gemini-2.5-flash',
    'gemini-2.5-flash-lite',
    'gemini-2.0-flash',
    'gemini-1.5-flash',
  ];

  static Future<String?> getApiKey() async {
    if (_envApiKey.trim().isNotEmpty) return _envApiKey.trim();

    final prefs = await SharedPreferences.getInstance();
    final storedKey = prefs.getString(_apiKeyKey);
    if (storedKey != null && storedKey.trim().isNotEmpty) {
      return storedKey.trim();
    }
    return defaultApiKey.trim().isNotEmpty ? defaultApiKey.trim() : null;
  }

  static Future<void> saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyKey, key.trim());
  }

  static Future<void> clearApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_apiKeyKey);
  }

  final String userName;
  final String currentMood;
  final List<Map<String, dynamic>> _chatHistory = [];

  GeminiService({required this.userName, required this.currentMood});

  List<Map<String, dynamic>> get chatHistory => _chatHistory;

  void addMessage({required String role, required String text}) {
    _chatHistory.add({
      'role': role == 'ai' ? 'model' : 'user',
      'parts': [
        {'text': text}
      ]
    });
  }

  Future<String> sendMessage(String message) async {
    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('API Key is missing. Please set your Gemini API key.');
    }

    addMessage(role: 'user', text: message);

    final systemInstruction =
        "You are a supportive, warm, and empathetic AI mental health companion named YouMatter AI. "
        "The user you are talking to is named $userName. "
        "Their current detected mood is '$currentMood'. "
        "Keep your responses relatively brief, supportive, and engaging. "
        "Encourage them to talk, offer soothing or positive words appropriate to their mood, and suggest constructive things they can do (matching their mood). "
        "Do not offer professional medical diagnosis or clinical therapy. Avoid overly academic language. "
        "Keep the conversation in the language they use to talk to you (Arabic or English). If they talk in Arabic, reply in friendly Egyptian Arabic or standard Arabic.";

    final body = {
      'contents': _chatHistory,
      'systemInstruction': {
        'parts': [
          {'text': systemInstruction}
        ]
      },
      'generationConfig': {
        'temperature': 0.7,
        'maxOutputTokens': 800,
      }
    };

    try {
      final aiText = await _generateWithFallback(apiKey, body);
      addMessage(role: 'ai', text: aiText);
      return aiText;
    } catch (e) {
      if (_chatHistory.isNotEmpty && _chatHistory.last['role'] == 'user') {
        _chatHistory.removeLast();
      }
      rethrow;
    }
  }

  Future<String> _generateWithFallback(
    String apiKey,
    Map<String, dynamic> body,
  ) async {
    String? lastError;

    for (final model in _modelCandidates) {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
      );

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final aiText = responseData['candidates']?[0]?['content']?['parts']?[0]
            ?['text'] as String?;

        if (aiText == null || aiText.trim().isEmpty) {
          throw Exception('Received empty response from Gemini.');
        }
        return aiText.trim();
      }

      String errorMessage = 'Status code: ${response.statusCode}';
      try {
        final errorBody = jsonDecode(response.body);
        errorMessage =
            errorBody['error']?['message']?.toString() ?? errorMessage;
      } catch (_) {}

      lastError = errorMessage;

      // Try next model if this one is missing/unsupported.
      final lower = errorMessage.toLowerCase();
      final tryNext = response.statusCode == 404 ||
          lower.contains('not found') ||
          lower.contains('no longer available') ||
          lower.contains('not supported');
      if (!tryNext) {
        throw Exception(errorMessage);
      }
    }

    throw Exception(lastError ?? 'Failed to get response from Gemini.');
  }
}
