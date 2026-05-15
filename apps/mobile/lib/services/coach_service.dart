import 'dart:async';
import 'package:flutter/material.dart';
import 'backend_service.dart';

class CoachMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  CoachMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

class CoachService {
  final BackendService _backend = BackendService();
  
  // Singleton pattern
  static final CoachService _instance = CoachService._internal();
  factory CoachService() => _instance;
  CoachService._internal();

  final List<CoachMessage> _messages = [];
  List<CoachMessage> get messages => List.unmodifiable(_messages);

  final _messageController = StreamController<List<CoachMessage>>.broadcast();
  Stream<List<CoachMessage>> get messageStream => _messageController.stream;

  void addMessage(String text, bool isUser) {
    _messages.add(CoachMessage(
      text: text,
      isUser: isUser,
      timestamp: DateTime.now(),
    ));
    _messageController.add(_messages);
  }

  Future<void> sendMessage(String text) async {
    addMessage(text, true);

    try {
      // Get context from backend to inject into prompt
      final stats = await _backend.fetchDashboardStats();
      final profile = await _backend.getUserProfile();
      final habits = await _backend.fetchBehavioralMetrics();
      
      // For now, we mock the AI response since the backend might not have the endpoint yet.
      // In a real scenario, this would call _backend.chatWithCoach(text, context);
      
      await Future.delayed(Duration(seconds: 1));
      
      String response = _getMockResponse(text, profile['name'] ?? 'there', stats['current_streak'] ?? 0);
      addMessage(response, false);
    } catch (e) {
      addMessage("I'm having trouble connecting right now. Let's try again in a moment.", false);
    }
  }

  String _getMockResponse(String text, String name, int streak) {
    if (text.toLowerCase().contains('hello') || text.toLowerCase().contains('hi')) {
      return "Good afternoon, $name! 🎯 12 days strong — you're building something real here. How can I help you today?";
    }
    if (text.toLowerCase().contains('streak')) {
      return "🔥 $streak days of consistency is genuinely impressive. One miss doesn't erase that. The goal now is just today. Which habit feels most doable right now?";
    }
    return "That's a great point. Let's break that goal down into a daily micro-habit. **Next Step:** What's the smallest version of this action you can do in under 2 minutes?";
  }
}
