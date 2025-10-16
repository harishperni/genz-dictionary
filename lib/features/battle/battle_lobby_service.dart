import 'package:cloud_firestore/cloud_firestore.dart';
import 'battle_lobby_model.dart';

class BattleLobbyService {
  final _db = FirebaseFirestore.instance;
  static const _collection = 'battle_lobbies';

  Future<String> createLobby({
    required String userId,
    required List<String> questions,
  }) async {
    final code = _generateLobbyCode();
    final lobby = BattleLobby(
      id: code,
      hostId: userId,
      guestId: null,
      questions: questions,
      status: 'waiting',
      createdAt: DateTime.now(),
    );

    await _db.collection(_collection).doc(code).set(lobby.toMap());
    return code;
  }

  Future<bool> joinLobby(String code, String userId) async {
    final ref = _db.collection(_collection).doc(code);
    final snap = await ref.get();
    if (!snap.exists) return false;

    final lobby = BattleLobby.fromMap(snap.data()!, code);
    if (lobby.guestId != null) return false; // already taken

    await ref.update({
      'guestId': userId,
      'status': 'active',
    });

    return true;
  }

  Stream<BattleLobby?> watchLobby(String code) {
    return _db.collection(_collection).doc(code).snapshots().map((snap) {
      if (!snap.exists) return null;
      return BattleLobby.fromMap(snap.data()!, code);
    });
  }

  String _generateLobbyCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final now = DateTime.now().microsecondsSinceEpoch;
    return List.generate(6, (i) => chars[(now + i * 37) % chars.length]).join();
  }
}