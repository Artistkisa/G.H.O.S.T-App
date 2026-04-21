import 'package:dio/dio.dart';
import 'config_service.dart';

/// Ghost HTTP API 封装
class GhostApi {
  static Dio? _dio;

  static Future<Dio> _getDio() async {
    if (_dio != null) return _dio!;
    final baseUrl = await ConfigService.getBaseUrl();
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ));
    return _dio!;
  }

  /// 上传图片
  static Future<Map<String, dynamic>> uploadImage(String filePath) async {
    final dio = await _getDio();
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    final response = await dio.post('/upload-image', data: formData);
    return response.data as Map<String, dynamic>;
  }

  /// 上传文档（pdf/docx/txt 等）
  static Future<Map<String, dynamic>> uploadFile(String filePath) async {
    final dio = await _getDio();
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    final response = await dio.post('/upload', data: formData);
    return response.data as Map<String, dynamic>;
  }

  /// 获取 Ghost 状态（情绪/grudges/workload）
  static Future<Map<String, dynamic>> getState() async {
    final dio = await _getDio();
    final response = await dio.get('/state');
    return response.data as Map<String, dynamic>;
  }

  /// 获取日记
  static Future<Map<String, dynamic>> getDiary() async {
    final dio = await _getDio();
    final response = await dio.get('/diary');
    return response.data as Map<String, dynamic>;
  }
}
