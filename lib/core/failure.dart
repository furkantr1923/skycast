import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

/// Uygulamadaki tüm veri hatalarının türü. Arayüz bu türe bakarak
/// Türkçe, anlaşılır bir mesaj gösterir; hiçbir hata uygulamayı çökertmez.
enum FailureKind {
  offline,
  timeout,
  rateLimited,
  server,
  invalidResponse,
  notSupported,
  permissionDenied,
  locationDisabled,
  unknown,
}

class AppFailure implements Exception {
  const AppFailure(this.kind, {this.source, this.detail});

  final FailureKind kind;

  /// Hatanın geldiği veri kaynağı (ör. "Open-Meteo").
  final String? source;
  final String? detail;

  String get title => switch (kind) {
        FailureKind.offline => 'İnternet bağlantısı yok',
        FailureKind.timeout => 'Sunucu zamanında yanıt vermedi',
        FailureKind.rateLimited => 'İstek sınırına ulaşıldı',
        FailureKind.server => 'Veri kaynağı şu an hizmet veremiyor',
        FailureKind.invalidResponse => 'Veri kaynağından geçersiz yanıt geldi',
        FailureKind.notSupported => 'Bu konum için veri yok',
        FailureKind.permissionDenied => 'Konum izni verilmedi',
        FailureKind.locationDisabled => 'Konum servisi kapalı',
        FailureKind.unknown => 'Beklenmeyen bir hata oluştu',
      };

  String get message => switch (kind) {
        FailureKind.offline =>
          'Eski hava durumu verileri güncelmiş gibi gösterilmez. Bağlantınızı kontrol edip yeniden deneyin.',
        FailureKind.timeout => 'Bağlantı yavaş olabilir. Biraz sonra yeniden deneyin.',
        FailureKind.rateLimited =>
          'Ücretsiz veri kaynağının kullanım sınırı aşıldı. Birkaç dakika sonra yeniden deneyin.',
        FailureKind.server => 'Kaynak geçici olarak kullanılamıyor. Uygulamanın geri kalanı çalışmaya devam eder.',
        FailureKind.invalidResponse => 'Gelen veri okunamadı. Daha sonra yeniden deneyin.',
        FailureKind.notSupported => 'Seçilen kaynak bu bölgeyi kapsamıyor.',
        FailureKind.permissionDenied =>
          'Konumunuzu kullanmak için izin gerekir. Şehir aramasıyla devam edebilirsiniz.',
        FailureKind.locationDisabled =>
          'Cihazın konum servisini açın ya da şehir aramasını kullanın.',
        FailureKind.unknown => 'Lütfen yeniden deneyin.',
      };

  @override
  String toString() => 'AppFailure($kind, source: $source, detail: $detail)';

  /// Herhangi bir hatayı [AppFailure]'a çevirir.
  static AppFailure from(Object error, {String? source}) {
    if (error is AppFailure) return error;
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return AppFailure(FailureKind.timeout, source: source, detail: error.message);
        case DioExceptionType.connectionError:
          return AppFailure(FailureKind.offline, source: source, detail: error.message);
        case DioExceptionType.badResponse:
          final code = error.response?.statusCode ?? 0;
          if (code == 429) return AppFailure(FailureKind.rateLimited, source: source);
          if (code == 404) return AppFailure(FailureKind.notSupported, source: source);
          if (code >= 500) return AppFailure(FailureKind.server, source: source, detail: '$code');
          return AppFailure(FailureKind.invalidResponse, source: source, detail: 'HTTP $code');
        case DioExceptionType.unknown:
          if (error.error is SocketException) {
            return AppFailure(FailureKind.offline, source: source, detail: '${error.error}');
          }
          return AppFailure(FailureKind.unknown, source: source, detail: error.message);
        default:
          return AppFailure(FailureKind.unknown, source: source, detail: error.message);
      }
    }
    if (error is SocketException) return AppFailure(FailureKind.offline, source: source);
    if (error is TimeoutException) return AppFailure(FailureKind.timeout, source: source);
    if (error is FormatException || error is TypeError) {
      return AppFailure(FailureKind.invalidResponse, source: source, detail: '$error');
    }
    return AppFailure(FailureKind.unknown, source: source, detail: '$error');
  }
}
