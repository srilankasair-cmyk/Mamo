import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'models.dart';
import 'package:uuid/uuid.dart';
import 'firebase_env.dart';

class PartyStore extends ChangeNotifier {
  static const _kKey = 'parties_v1';
  static const Duration _cloudTimeout = Duration(seconds: 8);
  final SharedPreferences prefs;
  final FirebaseFirestore? firestore;
  List<Party> parties = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  String? lastSyncError;
  bool isInitialLoading = false;
  bool isSyncing = false;
  bool isActionLoading = false;
  String? loadingAction;

  PartyStore._(this.prefs, this.firestore);

  static Future<PartyStore> create() async {
    final prefs = await SharedPreferences.getInstance();
    FirebaseFirestore? firestore;
    final firebaseReady = await FirebaseEnv.initializeIfConfigured();
    if (firebaseReady) {
      firestore = FirebaseFirestore.instance;
    }

    final s = PartyStore._(prefs, firestore);
    s.isInitialLoading = true;
    s.notifyListeners();
    await s._loadInitial();
    s.isInitialLoading = false;
    s.notifyListeners();
    s._startRemoteSync();
    return s;
  }

  CollectionReference<Map<String, dynamic>>? get _partiesCollection => firestore?.collection('parties');
  bool get cloudEnabled => firestore != null;

  Future<void> _loadInitial() async {
    _loadLocal();
    if (firestore != null) {
      unawaited(refreshFromCloud());
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
    isSyncing = true;
    notifyListeners();
    try {
      final snapshot = await _partiesCollection!.get().timeout(_cloudTimeout);
      parties = snapshot.docs.map((d) {
        final map = d.data();
        map['id'] = (map['id'] as String?) ?? d.id;
        return Party.fromJson(map);
      }).toList()
        ..sort((a, b) => a.time.compareTo(b.time));
      lastSyncError = null;
    } catch (e) {
      lastSyncError = 'Cloud read failed: $e';
    } finally {
      isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> refreshFromCloud() async {
    if (_partiesCollection == null) return;
    await _loadRemote();
    await _saveLocal(notify: false);
    notifyListeners();
  }

  Future<T> _runAction<T>(String action, Future<T> Function() task) async {
    isActionLoading = true;
    loadingAction = action;
    notifyListeners();
    try {
      return await task();
    } finally {
      isActionLoading = false;
      loadingAction = null;
      notifyListeners();
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
      await _partiesCollection!.doc(p.id).set(p.toJson()).timeout(_cloudTimeout);
      lastSyncError = null;
      notifyListeners();
      return true;
    } catch (e) {
      lastSyncError = 'Cloud write failed: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> _deletePartyFromRemote(String id) async {
    if (_partiesCollection == null) return false;
    try {
      await _partiesCollection!.doc(id).delete().timeout(_cloudTimeout);
      lastSyncError = null;
      notifyListeners();
      return true;
    } catch (e) {
      lastSyncError = 'Cloud delete failed: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> _syncPartyToRemoteInBackground(Party p) async {
    if (_partiesCollection == null) return;
    await _savePartyToRemote(p);
  }

  Future<void> _deletePartyFromRemoteInBackground(String id) async {
    if (_partiesCollection == null) return;
    await _deletePartyFromRemote(id);
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
    return _runAction('publish', () async {
      final i = parties.indexWhere((item) => item.id == p.id);
      if (i == -1) {
        parties.add(p);
      } else {
        parties[i] = p;
      }
      await _saveLocal();
      unawaited(_syncPartyToRemoteInBackground(p));
      return true;
    });
  }

  Future<bool> updateParty(Party updated) async {
    return _runAction('save', () async {
      final i = parties.indexWhere((p) => p.id == updated.id);
      if (i != -1) parties[i] = updated;
      await _saveLocal();
      unawaited(_syncPartyToRemoteInBackground(updated));
      return true;
    });
  }

  Future<bool> deleteParty(String id) async {
    return _runAction('delete', () async {
      parties.removeWhere((p) => p.id == id);
      await _saveLocal();
      unawaited(_deletePartyFromRemoteInBackground(id));
      return true;
    });
  }

  Future<bool> register(String partyId, String email, String diet) async {
    return _runAction('register', () async {
      final p = byId(partyId);
      if (p == null) return false;
      if (p.registrations.any((r) => r.email.toLowerCase() == email.toLowerCase())) return false;
      if (p.limit != null && p.registrations.length >= p.limit!) return false;
      p.registrations.add(Registration(email: email, diet: diet));
      await _saveLocal();
      unawaited(_syncPartyToRemoteInBackground(p));
      return true;
    });
  }

  Future<bool> ensurePartyExists(Party party) async {
    return _runAction('save', () async {
      final existing = byId(party.id);
      if (existing != null) {
        return true;
      }

      parties.add(party);
      await _saveLocal();
      unawaited(_syncPartyToRemoteInBackground(party));
      return true;
    });
  }

  String nextId() => const Uuid().v4();

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
