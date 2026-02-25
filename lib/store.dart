import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'models.dart';
import 'package:uuid/uuid.dart';
import 'firebase_env.dart';

class PartyStore extends ChangeNotifier {
  static const _kKey = 'parties_v1';
  final SharedPreferences prefs;
  final FirebaseFirestore? firestore;
  List<Party> parties = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  String? lastSyncError;

  PartyStore._(this.prefs, this.firestore);

  static Future<PartyStore> create() async {
    final prefs = await SharedPreferences.getInstance();
    FirebaseFirestore? firestore;
    final firebaseReady = await FirebaseEnv.initializeIfConfigured();
    if (firebaseReady) {
      firestore = FirebaseFirestore.instance;
    }

    final s = PartyStore._(prefs, firestore);
    await s._loadInitial();
    s._startRemoteSync();
    return s;
  }

  CollectionReference<Map<String, dynamic>>? get _partiesCollection => firestore?.collection('parties');
  bool get cloudEnabled => firestore != null;

  Future<void> _loadInitial() async {
    _loadLocal();
    if (firestore != null) {
      await _loadRemote();
      await _saveLocal(notify: false);
      notifyListeners();
    }
  }

  void _loadLocal() {
    final data = prefs.getString(_kKey);
    if (data != null) {
      parties = decodeParties(data);
      parties.sort((a, b) => a.time.compareTo(b.time));
    }
    notifyListeners();
  }

  Future<void> _loadRemote() async {
    try {
      final snapshot = await _partiesCollection!.get();
      parties = snapshot.docs.map((d) {
        final map = d.data();
        map['id'] = (map['id'] as String?) ?? d.id;
        return Party.fromJson(map);
      }).toList()
        ..sort((a, b) => a.time.compareTo(b.time));
      lastSyncError = null;
    } catch (e) {
      lastSyncError = 'Cloud read failed: $e';
    }
  }

  void _startRemoteSync() {
    if (_partiesCollection == null) return;

    _subscription = _partiesCollection!.snapshots().listen((snapshot) async {
      parties = snapshot.docs.map((d) {
        final map = d.data();
        map['id'] = (map['id'] as String?) ?? d.id;
        return Party.fromJson(map);
      }).toList()
        ..sort((a, b) => a.time.compareTo(b.time));

      lastSyncError = null;

      await _saveLocal(notify: false);
      notifyListeners();
    }, onError: (Object e) {
      lastSyncError = 'Cloud sync failed: $e';
      notifyListeners();
    });
  }

  Future<void> _saveLocal({bool notify = true}) async {
    parties.sort((a, b) => a.time.compareTo(b.time));
    final ok = await prefs.setString(_kKey, encodeParties(parties));
    if (ok && notify) {
      notifyListeners();
    }
  }

  Future<bool> _savePartyToRemote(Party p) async {
    if (_partiesCollection == null) return false;
    try {
      await _partiesCollection!.doc(p.id).set(p.toJson());
      lastSyncError = null;
      return true;
    } catch (e) {
      lastSyncError = 'Cloud write failed: $e';
      return false;
    }
  }

  Future<bool> _deletePartyFromRemote(String id) async {
    if (_partiesCollection == null) return false;
    try {
      await _partiesCollection!.doc(id).delete();
      lastSyncError = null;
      return true;
    } catch (e) {
      lastSyncError = 'Cloud delete failed: $e';
      return false;
    }
  }

  List<Party> upcoming() => parties.where((p) => p.time.isAfter(DateTime.now())).toList();

  Party? byId(String id) {
    try {
      return parties.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<bool> addParty(Party p) async {
    parties.add(p);
    await _saveLocal();
    return await _savePartyToRemote(p);
  }

  Future<bool> updateParty(Party updated) async {
    final i = parties.indexWhere((p) => p.id == updated.id);
    if (i != -1) parties[i] = updated;
    await _saveLocal();
    return await _savePartyToRemote(updated);
  }

  Future<bool> deleteParty(String id) async {
    parties.removeWhere((p) => p.id == id);
    await _saveLocal();
    return await _deletePartyFromRemote(id);
  }

  Future<bool> register(String partyId, String email, String diet) async {
    final p = byId(partyId);
    if (p == null) return false;
    if (p.registrations.any((r) => r.email.toLowerCase() == email.toLowerCase())) return false;
    if (p.limit != null && p.registrations.length >= p.limit!) return false;
    p.registrations.add(Registration(email: email, diet: diet));
    await _saveLocal();
    await _savePartyToRemote(p);
    return true;
  }

  String nextId() => const Uuid().v4();

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
