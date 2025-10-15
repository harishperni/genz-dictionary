// lib/features/streak/streak_controller_firebase.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart'; 

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'streak_service_firebase.dart';

/// Riverpod provider for the Firebase-backed streak/badges state.
final streakFBProvider =
    StateNotifierProvider<StreakFBController, StreakFB>((ref) {
  final uid = FirebaseAuth.instance.currentUser!.uid;
  final service = StreakServiceFirebase(uid: uid);
  return StreakFBController(service);
});

class StreakFBController extends StateNotifier<StreakFB> {
  final StreakServiceFirebase service;
  StreamSubscription<StreakFB>? _sub;

  StreakFBController(this.service) : super(StreakFB.initial()) {
    _init();
  }

  static const milestones = [3, 7, 14, 30, 60, 100, 365];

  Future<void> _init() async {
    await service.touchToday();
    _sub?.cancel();
    _sub = service.watch().listen((s) => state = s);
  }

  bool get hasUnclaimed =>
      milestones.contains(state.currentStreak) &&
      !state.rewardsClaimed.contains(state.currentStreak);

  Future<void> claimTodayReward() async {
    final day = state.currentStreak;
    if (!milestones.contains(day)) return;
    if (state.rewardsClaimed.contains(day)) return;
    await service.claim(day);
  }

  Future<void> trackWordViewed(String term) => service.trackWordViewed(term);
  Future<void> trackShared() => service.trackShared();
  Future<void> trackQuizXP() => service.trackQuizXP();

  // Debug helpers
  Future<void> recomputeToday() => service.touchToday();
  // 👈 add this at the top

// ...

Future<void> debugJumpToDayAndTouch(int targetDay) async {
  // Use Firestore directly instead of accessing private _db
  final db = FirebaseFirestore.instance;
  final ref = db.collection('users').doc(service.uid);

  await db.runTransaction((tx) async {
    final snap = await tx.get(ref);
    final cur = StreakFB.fromMap(snap.data());

    final prepared = cur.copyWith(
      currentStreak: targetDay - 1,
      highestStreak: (targetDay - 1) > cur.highestStreak
          ? (targetDay - 1)
          : cur.highestStreak,
      lastActiveDate: DateTime.now().subtract(const Duration(days: 1)),
    );

    if (snap.exists) {
      tx.update(ref, prepared.toMap());
    } else {
      tx.set(ref, prepared.toMap());
    }
  });

  await service.touchToday();
}

Future<void> debugUnclaimDay(int day) async {
  final db = FirebaseFirestore.instance;
  final ref = db.collection('users').doc(service.uid);
  await ref.update({'rewardsClaimed': FieldValue.arrayRemove([day])});
}
  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}