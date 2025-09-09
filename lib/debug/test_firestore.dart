import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreTestPage extends StatelessWidget {
  const FirestoreTestPage({super.key});

  Future<void> _runTests(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final db = FirebaseFirestore.instance;

    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No user signed in")),
      );
      return;
    }

    try {
      // ✅ Test 1: Read your own doc
      final myDoc = await db.collection("users").doc(uid).get();
      print("My doc exists: ${myDoc.exists}");

      // ❌ Test 2: Try to read another user's doc
      final fakeUid = "someone_else_uid";
      await db.collection("users").doc(fakeUid).get();
      print("Unexpectedly read another user's doc!");
    } catch (e) {
      print("Expected error when reading other user’s doc: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Firestore Test")),
      body: Center(
        child: ElevatedButton(
          onPressed: () => _runTests(context),
          child: const Text("Run Firestore Tests"),
        ),
      ),
    );
  }
}