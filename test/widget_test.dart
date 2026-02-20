import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:genz_dictionary/features/slang/ui/favorites_page.dart';

void main() {
  testWidgets('Favorites page shows empty state by default',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: FavoritesPage(),
        ),
      ),
    );

    expect(find.text('No favorites yet'), findsOneWidget);
    expect(find.text('Tap the heart on any term to save it here.'), findsOneWidget);
  });
}
