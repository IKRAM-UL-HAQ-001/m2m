import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'api_service.dart';

class AppError {
  final String message;
  final String? detail;
  final AppErrorType type;

  const AppError({required this.message, this.detail, required this.type});
}

enum AppErrorType {
  network,
  timeout,
  server,
  auth,
  notFound,
  validation,
  unknown,
}

class ErrorHandler {
  static AppError handle(dynamic error) {
    if (error is DioException) {
      return _handleDioError(error);
    }
    if (error is ApiException) {
      return _handleStatusCode(error.statusCode, {'detail': error.message});
    }
    return const AppError(
      message: 'Something went wrong',
      type: AppErrorType.unknown,
    );
  }

  static AppError _handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionError:
        return const AppError(
          message: 'No internet connection',
          detail: 'Please check your network and try again',
          type: AppErrorType.network,
        );
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const AppError(
          message: 'Request timed out',
          detail: 'Server is taking too long. Try again.',
          type: AppErrorType.timeout,
        );
      case DioExceptionType.badResponse:
        return _handleStatusCode(
          error.response?.statusCode,
          error.response?.data,
        );
      default:
        return const AppError(
          message: 'Connection failed',
          detail: 'Please try again',
          type: AppErrorType.unknown,
        );
    }
  }

  static AppError _handleStatusCode(int? code, dynamic data) {
    final serverMsg = _extractServerMessage(data);

    switch (code) {
      case 400:
        return AppError(
          message: serverMsg ?? 'Invalid request',
          type: AppErrorType.validation,
        );
      case 401:
        return const AppError(
          message: 'Session expired',
          detail: 'Please login again',
          type: AppErrorType.auth,
        );
      case 403:
        return const AppError(
          message: 'Access denied',
          type: AppErrorType.auth,
        );
      case 404:
        return const AppError(
          message: 'Not found',
          type: AppErrorType.notFound,
        );
      case 429:
        return const AppError(
          message: 'Too many requests',
          detail: 'Please wait a moment',
          type: AppErrorType.server,
        );
      case 500:
      case 502:
      case 503:
        return const AppError(
          message: 'Server error',
          detail: 'We are working on it. Try again soon.',
          type: AppErrorType.server,
        );
      default:
        return AppError(
          message: serverMsg ?? 'Something went wrong',
          type: AppErrorType.unknown,
        );
    }
  }

  static String? _extractServerMessage(dynamic data) {
    if (data == null) return null;
    if (data is Map) {
      final value = data['error'] ?? data['message'] ?? data['detail'];
      return value?.toString();
    }
    return null;
  }

  static void showError(BuildContext context, dynamic error) {
    _showErrorSnackbar(context, handle(error));
  }

  static void _showErrorSnackbar(BuildContext context, AppError error) {
    final icon = _getErrorIcon(error.type);
    final color = _getErrorColor(error.type);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        backgroundColor: Colors.transparent,
        elevation: 0,
        duration: const Duration(seconds: 4),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      error.message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    if (error.detail != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        error.detail!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _getErrorIcon(AppErrorType type) {
    switch (type) {
      case AppErrorType.network:
        return Icons.wifi_off_rounded;
      case AppErrorType.timeout:
        return Icons.timer_off_rounded;
      case AppErrorType.auth:
        return Icons.lock_outline_rounded;
      case AppErrorType.server:
        return Icons.cloud_off_rounded;
      case AppErrorType.notFound:
        return Icons.search_off_rounded;
      case AppErrorType.validation:
        return Icons.warning_amber_rounded;
      default:
        return Icons.error_outline_rounded;
    }
  }

  static Color _getErrorColor(AppErrorType type) {
    switch (type) {
      case AppErrorType.network:
      case AppErrorType.timeout:
        return Colors.orange.shade700;
      case AppErrorType.auth:
        return Colors.red.shade600;
      case AppErrorType.server:
        return Colors.red.shade700;
      case AppErrorType.validation:
        return Colors.amber.shade800;
      default:
        return Colors.grey.shade800;
    }
  }
}
