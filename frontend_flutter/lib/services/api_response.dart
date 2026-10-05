import 'package:dio/dio.dart';

/// 读取响应中的降级标记。degraded 严格为 true 时返回 reason
/// （缺失或不是字符串时为 'unknown'），否则返回 null。
String? degradedReasonOf(Map<String, dynamic> data) {
  if (data['degraded'] != true) return null;
  final reason = data['reason'];
  return reason is String && reason.isNotEmpty ? reason : 'unknown';
}

/// 面向用户的错误文案：优先使用后端的 detail，原始异常不直接展示。
String errorMessage(Object error) {
  if (error is! DioException) return 'Something went wrong. Please try again.';

  final detail = _detailOf(error.response?.data);
  if (detail != null) return detail;

  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return 'The request timed out. Please try again.';
    case DioExceptionType.connectionError:
      return 'Cannot reach the server. Please check your connection.';
    default:
      break;
  }

  final status = error.response?.statusCode;
  if (status != null) return 'Server error ($status). Please try again later.';
  return 'Something went wrong. Please try again.';
}

String? _detailOf(dynamic data) {
  if (data is! Map) return null;
  final detail = data['detail'];
  if (detail is String && detail.isNotEmpty) return detail;
  // FastAPI 的参数校验错误（422）detail 是数组，不适合直接展示
  if (detail is List) return 'Invalid request.';
  return null;
}
