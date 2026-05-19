import 'dart:typed_data';
import 'package:dio/dio.dart';
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

  Future<Map<String, dynamic>> recognizeText(
    Uint8List bytes,
    String filename,
  ) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final response = await _dio.post(ApiConfig.ocrRecognize, data: formData);
    return response.data;
  }

  Future<Map<String, dynamic>> generateStory(
    List<String> words, {
    String difficulty = 'intermediate',
  }) async {
    final response = await _dio.post(ApiConfig.storyGenerate, data: {
      'words': words,
      'difficulty': difficulty,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> generateFillBlank(
    String english,
    String chinese, {
    List<String> words = const [],
  }) async {
    final response = await _dio.post(ApiConfig.storyFillBlank, data: {
      'english': english,
      'chinese': chinese,
      'words': words,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> saveRecord(Map<String, dynamic> record) async {
    final response = await _dio.post(ApiConfig.historySave, data: record);
    return response.data;
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
    return response.data;
  }

  Future<void> deleteRecord(int id) async {
    await _dio.delete('${ApiConfig.historyRecords}/$id');
  }
}
