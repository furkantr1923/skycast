import 'package:flutter_test/flutter_test.dart';
import 'package:skycast/data/providers/meteoalarm.dart';
import 'package:skycast/domain/alert.dart';
import 'package:skycast/domain/place.dart';

Map<String, dynamic> _w(String id, String area, String level, String type, String expires) => {
      'alert': {
        'identifier': id,
        'info': [
          {
            'language': 'de-DE',
            'event': 'STURMBÖEN',
            'area': [{'areaDesc': area}],
            'parameter': [],
          },
          {
            'language': 'en-GB',
            'event': 'Gale-force gusts',
            'headline': 'Official WARNING of GALE-FORCE GUSTS',
            'description': 'Gusts up to 80 km/h.',
            'onset': '2026-11-24T10:00:00+01:00',
            'expires': expires,
            'senderName': 'Deutscher Wetterdienst',
            'area': [{'areaDesc': area}],
            'parameter': [
              {'valueName': 'awareness_level', 'value': level},
              {'valueName': 'awareness_type', 'value': type},
            ],
          },
        ],
      },
    };

void main() {
  const berlin = Place(name: 'Berlin', latitude: 52.5, longitude: 13.4, region: 'Berlin', countryCode: 'DE');
  final now = DateTime.utc(2026, 11, 24, 12);

  test('Yalnızca konumla eşleşen ve süresi dolmamış resmî uyarılar alınır', () {
    final j = {
      'warnings': [
        _w('a', 'Stadt Berlin', '3; orange; Severe', '1; Wind', '2026-11-25T00:00:00+01:00'),
        _w('b', 'Kreis München', '2; yellow; Moderate', '1; Wind', '2026-11-25T00:00:00+01:00'),
        _w('c', 'Berlin Mitte', '2; yellow; Moderate', '10; Rain', '2026-11-23T00:00:00+01:00'),
      ],
    };
    final a = MeteoAlarmProvider.parse(j, berlin, now: now);
    expect(a.length, 1);
    expect(a.first.origin, AlertOrigin.official);
    expect(a.first.severity, AlertSeverity.orange);
    expect(a.first.type, AlertType.strongWind);
    expect(a.first.title, 'Gale-force gusts');
    expect(a.first.source, 'Deutscher Wetterdienst');
  });

  test('Türkiye kapsam dışı', () {
    expect(MeteoAlarmProvider.covers('TR'), isFalse);
    expect(MeteoAlarmProvider.covers('de'), isTrue);
  });
}
