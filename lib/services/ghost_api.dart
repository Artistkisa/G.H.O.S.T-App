import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'config_service.dart';

/// Ghost HTTP API 封装（含 SSE 流式对话）
class GhostApi {
  static Dio? _dio;

  static Future<Dio> _getDio() async {
    if (_dio != null) return _dio!;
    final baseUrl = await ConfigService.getBaseUrl();
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(minutes: 5),
    ));
    return _dio!;
  }

  /// SSE 流式对话
  static Stream<Map<String, dynamic>> streamChat(String text, {List<String>? images}) async* {
    final baseUrl = await ConfigService.getBaseUrl();
    final token = await ConfigService.getToken();
    final dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(minutes: 5),
    ));

    final response = await dio.post(
      '/api/v1/chat/stream',
      data: {'text': text, if (images != null && images.isNotEmpty) 'images': images},
      options: Options(
        headers: {'Authorization': 'Bearer $token'},
        responseType: ResponseType.stream,
      ),
    );

    final responseBody = response.data as ResponseBody;
    final buffer = StringBuffer();

    await for (final chunk in responseBody.stream) {
      buffer.write(utf8.decode(chunk));
      // SSE 以 \n\n 分隔事件
      while (true) {
        final raw = buffer.toString();
        final idx = raw.indexOf('\n\n');
        if (idx == -1) break;
        final eventBlock = raw.substring(0, idx);
        buffer.clear();
        if (raw.length > idx + 2) {
          buffer.write(raw.substring(idx + 2));
        }
        // 解析 data: 行
        for (final line in eventBlock.split('\n')) {
          if (line.startsWith('data: ')) {
            final jsonStr = line.substring(6).trim();
            if (jsonStr.isNotEmpty && jsonStr != '[DONE]') {
              try {
                yield jsonDecode(jsonStr) as Map<String, dynamic>;
              } catch (_) {}
            }
          }
        }
      }
    }
  }

  /// 健康检查（HTTP GET /state）
  static Future<bool> healthCheck() async {
    try {
      final dio = await _getDio();
      final token = await ConfigService.getToken();
      await dio.get(
        '/state',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return true;
    } catch (_) {
      return false;
    }
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
