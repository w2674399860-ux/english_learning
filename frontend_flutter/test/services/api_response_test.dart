import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:english_learning_app/services/api_response.dart';

DioException _dioError({
  DioExceptionType type = DioExceptionType.badResponse,
  int? statusCode,
  dynamic data,
}) {
  final options = RequestOptions(path: '/x');
  return DioException(
    requestOptions: options,
    type: type,
    response: statusCode == null
        ? null
        : Response(requestOptions: options, statusCode: statusCode, data: data),
  );
}

void main() {
  group('degradedReasonOf', () {
    test('未降级或缺字段时返回 null', () {
      expect(degradedReasonOf({'words': <String>[]}), isNull);
      expect(degradedReasonOf({'degraded': false, 'reason': null}), isNull);
    });

    test('degraded 为 true 时返回 reason', () {
      expect(
        degradedReasonOf({'degraded': true, 'reason': 'ocr_unavailable'}),
        'ocr_unavailable',
      );
    });

    test('reason 缺失或不是字符串时返回 unknown', () {
      expect(degradedReasonOf({'degraded': true}), 'unknown');
      expect(degradedReasonOf({'degraded': true, 'reason': 42}), 'unknown');
    });

    test('degraded 不是严格的 true 时视为未降级', () {
      expect(degradedReasonOf({'degraded': 'true', 'reason': 'x'}), isNull);
      expect(degradedReasonOf({'degraded': 1, 'reason': 'x'}), isNull);
    });
  });

  group('errorMessage', () {
    test('优先使用后端 detail', () {
      final e = _dioError(
        statusCode: 503,
        data: {'detail': 'AI service is unavailable. Please try again later.'},
      );
      expect(
        errorMessage(e),
        'AI service is unavailable. Please try again later.',
      );
    });

    test('detail 为数组（校验错误）时显示通用文案', () {
      final e = _dioError(
        statusCode: 422,
        data: {
          'detail': [
            {'msg': 'field required'},
          ],
        },
      );
      expect(errorMessage(e), '请求参数有误。');
    });

    test('超时', () {
      expect(
        errorMessage(_dioError(type: DioExceptionType.receiveTimeout)),
        '请求超时，请重试。',
      );
      expect(
        errorMessage(_dioError(type: DioExceptionType.connectionTimeout)),
        '请求超时，请重试。',
      );
    });

    test('连不上服务器', () {
      expect(
        errorMessage(_dioError(type: DioExceptionType.connectionError)),
        '无法连接服务器，请检查网络。',
      );
    });

    test('响应体不是 JSON 时按状态码兜底', () {
      final e = _dioError(statusCode: 500, data: 'Internal Server Error');
      expect(errorMessage(e), '服务器出错（500），请稍后再试。');
    });

    test('非 Dio 异常不暴露原始文本', () {
      expect(errorMessage(const FormatException('boom')), '出了点问题，请重试。');
    });
  });

  group('classifyFlowError', () {
    test('连不上服务器：network', () {
      expect(
        classifyFlowError(_dioError(type: DioExceptionType.connectionError)),
        FlowErrorKind.network,
      );
    });

    test('超时与 5xx：可重试', () {
      for (final type in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      ]) {
        expect(classifyFlowError(_dioError(type: type)), FlowErrorKind.retryable);
      }
      for (final status in [500, 502, 503, 504]) {
        expect(
          classifyFlowError(_dioError(statusCode: status)),
          FlowErrorKind.retryable,
          reason: '$status',
        );
      }
    });

    test('429、400（不是图片）、413（图片太大）、422：不可重试', () {
      for (final status in [400, 413, 422, 429]) {
        expect(
          classifyFlowError(_dioError(statusCode: status)),
          FlowErrorKind.notRetryable,
          reason: '$status',
        );
      }
    });

    test('非 Dio 异常（如读取图片失败）按可重试处理', () {
      expect(classifyFlowError(const FormatException('x')), FlowErrorKind.retryable);
    });
  });
}
