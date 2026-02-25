import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'package:uuid/uuid.dart';

class PartyStore extends ChangeNotifier {
  static const _kKey = 'parties_v1';
  final SharedPreferences prefs;
  List<Party> parties = [];

  PartyStore._(this.prefs);

  static Future<PartyStore> create() async {
    final prefs = await SharedPreferences.getInstance();
    final s = PartyStore._(prefs);
    s._load();
    return s;
  }

  void _load() {
    final data = prefs.getString(_kKey);
    if (data != null) {
      parties = decodeParties(data);
      parties.sort((a, b) => a.time.compareTo(b.time));
    }
    notifyListeners();
  }

  Future<void> _save() async {
    parties.sort((a, b) => a.time.compareTo(b.time));
    await prefs.setString(_kKey, encodeParties(parties));
    notifyListeners();
  }

  List<Party> upcoming() => parties.where((p) => p.time.isAfter(DateTime.now())).toList();

  Party? byId(String id) {
    try {
      return parties.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> addParty(Party p) async {
    parties.add(p);
    await _save();
  }

  Future<void> updateParty(Party updated) async {
    final i = parties.indexWhere((p) => p.id == updated.id);
    if (i != -1) parties[i] = updated;
    await _save();
  }

  Future<void> deleteParty(String id) async {
    parties.removeWhere((p) => p.id == id);
    await _save();
  }

  Future<bool> register(String partyId, String email, String diet) async {
    final p = byId(partyId);
    if (p == null) return false;
    if (p.registrations.any((r) => r.email.toLowerCase() == email.toLowerCase())) return false;
    if (p.limit != null && p.registrations.length >= p.limit!) return false;
    p.registrations.add(Registration(email: email, diet: diet));
    await _save();
    return true;
  }

  String nextId() => const Uuid().v4();
}
