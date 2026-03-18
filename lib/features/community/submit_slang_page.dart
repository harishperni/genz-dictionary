import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SubmitSlangPage extends StatefulWidget {
  const SubmitSlangPage({super.key});

  @override
  State<SubmitSlangPage> createState() => _SubmitSlangPageState();
}

class _SubmitSlangPageState extends State<SubmitSlangPage> {
  final _formKey = GlobalKey<FormState>();
  final _term = TextEditingController();
  final _meaning = TextEditingController();
  final _example = TextEditingController();
  final _tags = TextEditingController();

  bool _saving = false;

  @override
  void dispose() {
    _term.dispose();
    _meaning.dispose();
    _example.dispose();
    _tags.dispose();
    super.dispose();
  }

  List<String> _normalizeTags(String raw) {
    return raw
        .split(',')
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet()
        .take(8)
        .toList();
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in first.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('community_submissions').add({
        'uid': user.uid,
        'term': _term.text.trim(),
        'meaning': _meaning.text.trim(),
        'example': _example.text.trim(),
        'tags': _normalizeTags(_tags.text),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Submitted. We will review it soon.')),
      );

      _term.clear();
      _meaning.clear();
      _example.clear();
      _tags.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Submission failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Submit Slang')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D1021), Color(0xFF1F1147)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                child: const Text(
                  'Drop your slang. If approved, it can appear in future updates.',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _term,
                      decoration: const InputDecoration(labelText: 'Term'),
                      validator: (v) {
                        final t = (v ?? '').trim();
                        if (t.length < 2) return 'Term is too short.';
                        if (t.length > 24) return 'Term is too long.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _meaning,
                      decoration: const InputDecoration(labelText: 'Meaning'),
                      minLines: 2,
                      maxLines: 4,
                      validator: (v) =>
                          (v ?? '').trim().isEmpty ? 'Meaning is required.' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _example,
                      decoration:
                          const InputDecoration(labelText: 'Example sentence'),
                      minLines: 2,
                      maxLines: 4,
                      validator: (v) =>
                          (v ?? '').trim().isEmpty ? 'Example is required.' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _tags,
                      decoration: const InputDecoration(
                        labelText: 'Tags (comma separated)',
                        hintText: 'funny, school, gaming',
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _submit,
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send_rounded),
                        label: Text(_saving ? 'Submitting...' : 'Submit Slang'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
