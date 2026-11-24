import 'package:dio/dio.dart';

import 'failure.dart';

/// Tüm veri kaynakları için ortak HTTP istemcisi.
///
/// Kimlik bilgisi yok: SKYCAST yalnızca anahtarsız, ücretsiz kaynakları kullanır.
class Http {
  Http._();

  static const userAgent = 'SKYCAST/1.0 (+https://github.com/furkantr1923/skycast)';

  static final Dio dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 12),
      responseType: ResponseType.json,
      headers: {'User-Agent': userAgent, 'Accept': 'application/json'},
    ),
  );

  /// JSON getirir; hataları [AppFailure]'a çevirir.
  static Future<dynamic> getJson(
    String url, {
    Map<String, dynamic>? query,
    required String source,
    CancelToken? cancelToken,
  }) async {
    try {
      final res = await dio.get<dynamic>(url, queryParameters: query, cancelToken: cancelToken);
      final data = res.data;
      if (data == null) throw AppFailure(FailureKind.invalidResponse, source: source);
      if (data is Map && data['error'] == true) {
        throw AppFailure(FailureKind.invalidResponse, source: source, detail: '${data['reason']}');
      }
      return data;
    } catch (e) {
      throw AppFailure.from(e, source: source);
    }
  }

  /// Bir adresin erişilebilir olup olmadığını (HTTP durum kodu) döndürür.
  /// Yalnızca öz-sınama raporunda kullanılır.
  static Future<int> status(String url) async {
    try {
      final res = await dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes, validateStatus: (_) => true),
      );
      return res.statusCode ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<String> getText(String url, {required String source}) async {
    try {
      final res = await dio.get<String>(url, options: Options(responseType: ResponseType.plain));
      return res.data ?? '';
    } catch (e) {
      throw AppFailure.from(e, source: source);
    }
  }
}
