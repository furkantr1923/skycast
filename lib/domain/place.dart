/// Kullanıcının seçebildiği bir konum (şehir, GPS noktası ya da haritada dokunulan yer).
class Place {
  const Place({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.region,
    this.country,
    this.countryCode,
    this.isGps = false,
  });

  final String name;
  final double latitude;
  final double longitude;
  final String? region;
  final String? country;
  final String? countryCode;
  final bool isGps;

  /// Aynı yeri tanımlamak için yuvarlanmış koordinat anahtarı.
  String get key => '${latitude.toStringAsFixed(3)},${longitude.toStringAsFixed(3)}';

  String get subtitle => [region, country].whereType<String>().where((s) => s.isNotEmpty && s != name).join(', ');

  Place copyWith({String? name, String? region, String? country, String? countryCode, bool? isGps}) => Place(
        name: name ?? this.name,
        latitude: latitude,
        longitude: longitude,
        region: region ?? this.region,
        country: country ?? this.country,
        countryCode: countryCode ?? this.countryCode,
        isGps: isGps ?? this.isGps,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'lat': latitude,
        'lon': longitude,
        'region': region,
        'country': country,
        'cc': countryCode,
      };

  factory Place.fromJson(Map<String, dynamic> j) => Place(
        name: j['name'] as String,
        latitude: (j['lat'] as num).toDouble(),
        longitude: (j['lon'] as num).toDouble(),
        region: j['region'] as String?,
        country: j['country'] as String?,
        countryCode: j['cc'] as String?,
      );

  @override
  bool operator ==(Object other) => other is Place && other.key == key;

  @override
  int get hashCode => key.hashCode;
}
