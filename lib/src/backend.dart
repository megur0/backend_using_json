import 'dart:convert';

import 'package:flutter/foundation.dart';

enum RequestType {
  get,
  post,
}

typedef Response<T, E> = ({List<T> data, E? error});

@immutable
abstract base class Request<T> {
  const Request({
    required this.type,
    required this.token,
    required this.path,
    required this.fromJson,
    this.pathParam,
    this.pathParamSymbols,
    this.query,
    this.body,
  })  : assert(!(pathParam != null && pathParamSymbols == null),
            'Symbols should be specified for each path param'),
        assert(!(pathParam == null && pathParamSymbols != null),
            'Path param is not set, so symbols will never be used'),
        assert(!(type == RequestType.get && body != null),
            'Body should be null because request method is get');
  final RequestType type;
  final String token;
  final String path;
  final List<String>? pathParam;
  final List<String>? pathParamSymbols;
  final Map<String, String>? query;
  final Map<String, dynamic>? body;
  final T Function(Map<String, dynamic> jsonMap)? fromJson;

  @override
  String toString() =>
      '_${runtimeType.toString()}(${_getPathWithReplacedPathParamValue(this)})';
}

class BackendUsingJson<E> {
  BackendUsingJson({
    required this.httpGet,
    required this.httpPost,
    required this.endpoint,
    required this.resultHandler,
  });

  final String endpoint;

  final Future<(int statusCode, String responseBody)> Function(
    String token,
    Uri url,
  ) httpGet;

  final Future<(int statusCode, String responseBody)> Function(
      String token, Uri url, Map<String, dynamic>? body) httpPost;

  final Response<T, E> Function<T>(
    int statusCode,
    Map<String, dynamic> responseBody,
    T Function(Map<String, dynamic> jsonMap)? fromJson,
    Request<T> request,
  ) resultHandler;

  Future<Response<T, E>> request<T>(
      Request<T> request,
      Response<T, E> Function<T>(Object? error, StackTrace? stackTrace)?
          errorHandler) async {
    final url = _getUrl(endpoint, _getPathWithReplacedPathParamValue(request),
        request.query ?? {});

    late final int statusCode;
    late final String responseBody;
    late final Map<String, dynamic> json;
    late final Response<T, E> result;

    try {
      switch (request.type) {
        case RequestType.get:
          (statusCode, responseBody) = await httpGet(
            request.token,
            url,
          );
        case RequestType.post:
          (statusCode, responseBody) =
              await httpPost(request.token, url, request.body);
      }
      json = jsonDecode(responseBody);
      result = resultHandler(statusCode, json, request.fromJson, request);
    } catch (e, s) {
      if (errorHandler == null) {
        rethrow;
      }
      return errorHandler(e, s);
    }

    return result;
  }
}

// パスに含まれるすべてのパスパラメータを値に置換した文字列返す。
String _getPathWithReplacedPathParamValue(Request request) {
  assert((request.pathParamSymbols == null && request.pathParam == null) ||
      (request.pathParamSymbols != null && request.pathParam != null));
  if (request.pathParamSymbols == null) {
    return request.path;
  }
  assert(request.pathParamSymbols!.length == request.pathParam!.length);
  String after = request.path;
  for (int i = 0; i < request.pathParamSymbols!.length; i++) {
    after =
        after.replaceAll(request.pathParamSymbols![i], request.pathParam![i]);
  }
  return after;
}

Uri _getUrl(String endpoint, String path, Map<String, String> query) {
  final q = query.entries.map((e) => '${e.key}=${e.value}').toList();
  final url = Uri.parse([
    endpoint,
    "$path${q.isNotEmpty ? '?' : ''}${q.join('&')}",
  ].join("/"));
  return url;
}
