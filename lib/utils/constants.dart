import 'package:flutter/material.dart';

class AppColors {
  static const primaryColor = Color(0xFF9B10A3); // Vibrant purple from the logo
  static const unselectedColor = Color(0xFFB238B8); // Slightly lighter purple
  static const floatingButtonColor = Color(0xFFD500F9); // Bright purple accent
  static const outgoingMessageColor = Color(
    0xFFF3E5F5,
  ); // Light purple for text bubbles
  static const chatBackgroundColor = Color(
    0xFFEEE5EE,
  ); // Light greyish purple for chat background
  static const scaffoldBackgroundColor = Colors.white;
}

class AppConstants {
  static const String serverIp = '127.0.0.1:8000';
  static const String apiBaseUrl = 'http://$serverIp/api';
  static const String authBaseUrl = 'http://$serverIp/auth';
  static const String wsBaseUrl = 'ws://$serverIp/ws/chat/';
}
