import 'package:dio/dio.dart';

import '../l10n/l10n.dart';

/// 读取响应中的降级标记。degraded 严格为 true 时返回 reason
/// （缺失或不是字符串时为 'unknown'），否则返回 null。
String? degradedReasonOf(Map<String, dynamic> data) {
  if (data['degraded'] != true) return null;
  final reason = data['reason'];
  return reason is String && reason.isNotEmpty ? reason : 'unknown';
}

/// 面向用户的错误文案：优先使用后端的 detail，原始异常不直接展示。
String errorMessage(Object error) {
  if (error is! DioException) return appL10n.errorGeneric;

  final detail = _detailOf(error.response?.data);
  if (detail != null) return detail;

  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return appL10n.errorTimeout;
    case DioExceptionType.connectionError:
      return appL10n.errorNetwork;
    default:
      break;
  }

  final status = error.response?.statusCode;
  if (status != null) return appL10n.errorServer(status);
  return appL10n.errorGeneric;
}

/// 识别 / 生成失败的类别，决定界面显示什么（第 3 批，已批准）。
enum FlowErrorKind {
  /// 连不上服务器：显示网络错误画面，可以重试。
  network,

  /// 超时、5xx（服务暂不可用）等：重试可能成功。
  retryable,

  /// 429 次数用完、400 不是图片、413 图片太大、422 参数错误等：重试没有意义，不显示"重试"。
  notRetryable,
}

FlowErrorKind classifyFlowError(Object error) {
  if (error is! DioException) return FlowErrorKind.retryable;
  switch (error.type) {
    case DioExceptionType.connectionError:
      return FlowErrorKind.network;
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return FlowErrorKind.retryable;
    case DioExceptionType.cancel:
      return FlowErrorKind.notRetryable;
    default:
      break;
  }
  final status = error.response?.statusCode;
  if (status == null) return FlowErrorKind.retryable;
  return status >= 500 ? FlowErrorKind.retryable : FlowErrorKind.notRetryable;
}

/// 是否为限流（429）。429 的 detail 已带中文与大致等待时间，界面不显示"重试"。
bool isRateLimited(Object error) =>
    error is DioException && error.response?.statusCode == 429;

/// 429 响应头 Retry-After 的秒数（后端 CORS 已暴露该头）。缺失或不是非负整数时返回 null。
Duration? retryAfterOf(Object error) {
  if (error is! DioException) return null;
  final raw = error.response?.headers.value('retry-after');
  final seconds = int.tryParse(raw?.trim() ?? '');
  if (seconds == null || seconds < 0) return null;
  return Duration(seconds: seconds);
}

String? _detailOf(dynamic data) {
  if (data is! Map) return null;
  final detail = data['detail'];
  if (detail is String && detail.isNotEmpty) return detail;
  // FastAPI 的参数校验错误（422）detail 是数组，不适合直接展示
  if (detail is List) return appL10n.errorInvalidRequest;
  return null;
}
