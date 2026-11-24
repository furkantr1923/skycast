import '../core/failure.dart';

enum LoadStatus { idle, loading, ready, error }

/// Bir veri parçasının durumu. Hata durumunda veri TUTULMAZ: bağlantı
/// kesildiğinde eski veri güncelmiş gibi gösterilmesin diye.
class Load<T> {
  const Load._(this.status, this.data, this.failure);

  const Load.idle() : this._(LoadStatus.idle, null, null);
  const Load.loading() : this._(LoadStatus.loading, null, null);
  const Load.ready(T value) : this._(LoadStatus.ready, value, null);
  const Load.error(AppFailure f) : this._(LoadStatus.error, null, f);

  final LoadStatus status;
  final T? data;
  final AppFailure? failure;

  bool get isLoading => status == LoadStatus.loading;
  bool get hasData => status == LoadStatus.ready && data != null;
  bool get hasError => status == LoadStatus.error;
}
