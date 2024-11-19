import 'dart:convert';

import 'package:dio/dio.dart';

class ClienteInterceptor implements Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    return handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        error: utf8.decode((err.error! as FormatException).source),
      ),
    );
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    // final responseData = response.data;
    // if (responseData is Map &&
    //     (responseData.keys.every(
    //       (e) => ['success', 'data', 'message'].contains(e),
    //     ))) {
    //   return handler.next(response);
    // }

    // return handler.reject(
    //   DioException(
    //     requestOptions: response.requestOptions,
    //     error: 'The response is not in valid format',
    //   ),
    // );
    return handler.next(response);
  }
}
