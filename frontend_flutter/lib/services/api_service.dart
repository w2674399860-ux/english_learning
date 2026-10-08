import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../auth/auth_interceptor.dart';
import '../config/api_config.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late final Dio _dio;

  ApiService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(milliseconds: ApiConfig.connectTimeout),
      receiveTimeout: const Duration(milliseconds: ApiConfig.receiveTimeout),
      headers: {'Content-Type': 'application/json'},
    ));
  }

  /// 与账号接口（DioAuthApi）共用同一个 Dio，凭证由同一个拦截器附加。
  Dio get dio => _dio;

  /// 挂上（或替换）鉴权拦截器。ApiService 是单例，重复调用不会叠加多个。
  void setAuthInterceptor(AuthInterceptor interceptor) {
    _dio.interceptors.removeWhere((i) => i is AuthInterceptor);
    _dio.interceptors.add(interceptor);
  }

  // 恢复为 Map 返回类型，但在内部做了安全的 String-to-Map 兼容包装
  Future<Map<String, dynamic>> recognizeText(
    Uint8List bytes,
    String filename,
  ) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final response = await _dio.post(ApiConfig.ocrRecognize, data: formData);
    
    final data = response.data;
    if (data is String) {
      // 兼容：如果后端返回的是纯文本，自动包装为 Map 结构
      return {'text': data, 'words': <String>[]};
    }
    return data as Map<String, dynamic>;
  }

  /// 一次请求生成短文、中译与中英文填空。
  Future<Map<String, dynamic>> composeLearning(
    List<String> words, {
    required String difficulty,
  }) async {
    final response = await _dio.post(ApiConfig.learnCompose, data: {
      'words': words,
      'difficulty': difficulty,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> saveRecord(Map<String, dynamic> record) async {
    final response = await _dio.post(ApiConfig.historySave, data: record);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getRecords({
    int page = 1,
    int pageSize = 20,
    String search = '',
  }) async {
    final response = await _dio.get(ApiConfig.historyRecords, queryParameters: {
      'page': page,
      'page_size': pageSize,
      'search': search,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<void> deleteRecord(int id) async {
    await _dio.delete('${ApiConfig.historyRecords}/$id');
  }
}