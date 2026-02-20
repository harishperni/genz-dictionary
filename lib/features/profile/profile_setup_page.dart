import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ProfileSetupPage extends StatefulWidget {
  const ProfileSetupPage({super.key});

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  final _controller = TextEditingController();
  bool _saving = false;
  bool _prefilled = false;

  bool get _isEditMode =>
      GoRouterState.of(context).uri.queryParameters['mode'] == 'edit';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_prefilled) return;
    _prefilled = true;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    FirebaseFirestore.instance.collection('users').doc(uid).get().then((snap) {
      if (!mounted) return;
      final existing = (snap.data()?['displayId'] ?? '').toString().trim();
      if (existing.isNotEmpty) {
        _controller.text = existing;
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _validate(String value) {
    final v = value.trim();
    if (v.length < 3) return 'Use at least 3 characters.';
    if (v.length > 20) return 'Use at most 20 characters.';
    final ok = RegExp(r'^[A-Za-z0-9_]+$').hasMatch(v);
    if (!ok) return 'Only letters, numbers, and underscore are allowed.';
    return null;
  }

  Future<void> _save() async {
    if (_saving) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final displayId = _controller.text.trim();
    final error = _validate(displayId);
    if (error != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    setState(() => _saving = true);
    try {
      final db = FirebaseFirestore.instance;
      final lower = displayId.toLowerCase();

      final sameIdSnap = await db
          .collection('users')
          .where('displayIdLower', isEqualTo: lower)
          .limit(1)
          .get();
      final takenByOther = sameIdSnap.docs.any((d) => d.id != uid);
      if (takenByOther) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('That ID is already taken.')),
        );
        return;
      }

      await db.collection('users').doc(uid).set({
        'displayId': displayId,
        'displayIdLower': lower,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      if (_isEditMode && Navigator.of(context).canPop()) {
        context.pop();
      } else {
        context.go('/');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save ID: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditMode ? 'Edit Your ID' : 'Set Your ID')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pick a public ID for battle screens.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
              decoration: const InputDecoration(
                hintText: 'e.g. rizz_master_07',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '3-20 chars, letters/numbers/underscore only.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isEditMode ? 'Save' : 'Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
