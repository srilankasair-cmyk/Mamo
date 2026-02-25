import 'dart:convert';

class Registration {
  String email;
  String diet;

  Registration({required this.email, required this.diet});

  factory Registration.fromJson(Map<String, dynamic> j) => Registration(email: j['email'], diet: j['diet']);
  Map<String, dynamic> toJson() => {'email': email, 'diet': diet};
}

class Party {
  String id;
  String title;
  DateTime time;
  double fee;
  int? limit; // null means unlimited
  String description;
  String? location;
  String? posterBase64; // optional image stored as base64
  List<Registration> registrations;

  Party({required this.id, required this.title, required this.time, required this.fee, this.limit, required this.description, this.location, this.posterBase64, List<Registration>? registrations}) : registrations = registrations ?? [];

  factory Party.fromJson(Map<String, dynamic> j) => Party(
        id: j['id'],
        title: j['title'],
        time: DateTime.parse(j['time']),
        fee: (j['fee'] as num).toDouble(),
        limit: j['limit'] == null ? null : (j['limit'] as num).toInt(),
        description: j['description'] ?? '',
        location: j['location'],
        posterBase64: j['posterBase64'],
        registrations: (j['registrations'] as List<dynamic>? ?? []).map((e) => Registration.fromJson(e)).toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'time': time.toIso8601String(),
        'fee': fee,
        'limit': limit,
        'description': description,
        'location': location,
        'posterBase64': posterBase64,
        'registrations': registrations.map((r) => r.toJson()).toList(),
      };

  String get timeLabel => time.toIso8601String();
}

List<Party> decodeParties(String jsonStr) {
  final arr = json.decode(jsonStr) as List<dynamic>;
  return arr.map((e) => Party.fromJson(e)).toList();
}

String encodeParties(List<Party> parties) => json.encode(parties.map((p) => p.toJson()).toList());
