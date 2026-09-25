import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'storage_service.dart';

class ApiService {
  static final Dio _dio = Dio(
    BaseOptions(
      // baseUrl: "http://172.20.10.4:8000/api", //physical device
       baseUrl: "http://10.0.9.223:8000/api",  //emulator device
      // baseUrl: "https://nextpay-j4pu.onrender.com/api",
      // ipconfig getifaddr en0
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  static Dio get instance => _dio;

  static void init() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await StorageService.getItem("token");
          if (token != null) {
            options.headers["Authorization"] = "Bearer $token";
          }
          debugPrint("REQUEST: ${options.method} ${options.uri}");
          return handler.next(options);
        },
        onError: (error, handler) {
          debugPrint("API ERROR: ${error.response?.statusCode} ${error.response?.data}");
          return handler.next(error);
        },
      ),
    );
  }
}