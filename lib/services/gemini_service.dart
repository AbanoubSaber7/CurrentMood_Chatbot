import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class GeminiService {
  static const String _apiKeyKey = 'gemini_api_key';
  
  // Place your hardcoded Gemini API Key here if desired.
  static const String defaultApiKey = '';

  static Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final storedKey = prefs.getString(_apiKeyKey);
    if (storedKey != null && storedKey.trim().isNotEmpty) {
      return storedKey;
    }
    return defaultApiKey.trim().isNotEmpty ? defaultApiKey : null;
  }

  static Future<void> saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyKey, key);
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

    // Add user message to history
    addMessage(role: 'user', text: message);

    final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey');

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
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode != 200) {
        // Remove user message from history if call failed
        _chatHistory.removeLast();
        final errorBody = jsonDecode(response.body);
        final errorMessage = errorBody['error']?['message'] ?? 'Status code: ${response.statusCode}';
        throw Exception(errorMessage);
      }

      final responseData = jsonDecode(response.body);
      final aiText = responseData['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;
      
      if (aiText == null || aiText.isEmpty) {
        _chatHistory.removeLast();
        throw Exception('Received empty response from Gemini.');
      }

      // Add AI response to history
      addMessage(role: 'ai', text: aiText);
      return aiText;
    } catch (e) {
      if (_chatHistory.isNotEmpty && _chatHistory.last['role'] == 'user') {
        _chatHistory.removeLast();
      }
      rethrow;
    }
  }
}
