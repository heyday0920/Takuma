import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_swipe_app/main.dart'; // Adjust import if your main.dart is in a different location e.g., '../lib/main.dart'

void main() {
  testWidgets('LoginScreen UI Test - Check for key elements and styling', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(RestaurantSwipeApp());

    // Verify LoginScreen is present.
    expect(find.byType(LoginScreen), findsOneWidget);

    // Verify email and password TextFields are present.
    expect(find.widgetWithText(TextField, 'メールアドレス'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'パスワード'), findsOneWidget);

    // Verify Login button is present and has new styling.
    final Finder loginButtonFinder = find.widgetWithText(ElevatedButton, 'ログイン');
    expect(loginButtonFinder, findsOneWidget);
    
    final ElevatedButton loginButton = tester.widget<ElevatedButton>(loginButtonFinder);
    final ButtonStyle? style = loginButton.style;
    final MaterialStateProperty<Color?>? backgroundColor = style?.backgroundColor;
    // Test the color resolved for the default state.
    expect(backgroundColor?.resolve({}), Colors.blueGrey[700]);
    
    final MaterialStateProperty<OutlinedBorder?>? shape = style?.shape;
    expect(shape?.resolve({}) is RoundedRectangleBorder, isTrue);
    final RoundedRectangleBorder? rrb = shape?.resolve({}) as RoundedRectangleBorder?;
    expect(rrb?.borderRadius, BorderRadius.circular(12.0));

    // Verify prefix icons in TextFields
    expect(find.byIcon(Icons.email), findsOneWidget);
    expect(find.byIcon(Icons.lock), findsOneWidget);
  });

  testWidgets('RestaurantSwipeScreen AppBar and Button UI Test', (WidgetTester tester) async {
    // Mock navigation to RestaurantSwipeScreen
    await tester.pumpWidget(MaterialApp(
      home: RestaurantSwipeScreen(), 
    ));

    // Verify AppBar title and new background color.
    final AppBar appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.title is Text, isTrue);
    expect((appBar.title as Text).data, '飲食店スワイプ');
    expect(appBar.backgroundColor, Colors.blueGrey[700]);

    // Verify LIKE button styling (isLoading is true initially, so buttons might not be visible)
    // We need to simulate data loading to see the main content
    // For simplicity, this test will assume restaurants list is empty and buttons are present.
    // A more robust test would mock the data fetching.
    
    // Let's assume `isLoading` becomes false and `restaurants` is empty to show buttons
    // This part is tricky without refactoring the widget for testability or complex state mocking.
    // For now, we'll check for the buttons if they are rendered.
    // If RestaurantSwipeScreen shows a loader or empty state, these might fail.
    // We will assume the widget is modified or can be put in a state where buttons are visible.

    // To properly test RestaurantSwipeScreen, we need to provide it with some restaurants
    // or mock its state. For this task, we'll focus on what's easily testable.
    // The buttons are part of the main column which is shown when not loading and restaurants not empty.
    // Let's assume a state where buttons are visible.
    
    // This test might need adjustment based on how RestaurantSwipeScreen handles state.
    // For now, we'll look for the buttons directly.
    final Finder nopeButtonFinder = find.widgetWithText(ElevatedButton, 'NOPE');
    final Finder likeButtonFinder = find.widgetWithText(ElevatedButton, 'LIKE');

    // Check if buttons are found (they might not be if loading state isn't handled)
    // Initially, isLoading is true, and a CircularProgressIndicator is shown.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // We need to advance past the loading state.
    // In a real test, you'd mock the Future that sets isLoading = false.
    // Here, we'll pump and settle to allow microtasks (like the initial Future in initState) to complete.
    // This assumes _getCurrentLocation completes and sets isLoading to false,
    // and that restaurants list is empty, leading to the "お店が見つかりませんでした" state
    // which *should* still display the NOPE/LIKE buttons according to the current layout.
    await tester.pumpAndSettle(); 

    // Now check for the buttons again.
    expect(nopeButtonFinder, findsOneWidget);
    expect(likeButtonFinder, findsOneWidget);

    if (tester.any(nopeButtonFinder)) {
      final ElevatedButton nopeButton = tester.widget<ElevatedButton>(nopeButtonFinder);
      expect(nopeButton.style?.backgroundColor?.resolve({}), Colors.redAccent[100]);
    }

    if (tester.any(likeButtonFinder)) {
      final ElevatedButton likeButton = tester.widget<ElevatedButton>(likeButtonFinder);
      expect(likeButton.style?.backgroundColor?.resolve({}), Colors.greenAccent[400]);
    }
    // NOTE: Testing the card itself (Material widget) requires restaurant data.
    // This test focuses on AppBar and action buttons.
  });

  testWidgets('RecommendedScreen AppBar UI Test and Empty State', (WidgetTester tester) async {
    // Mock navigation to RecommendedScreen
    // Provide minimal required parameters.
    await tester.pumpWidget(MaterialApp(
      home: RecommendedScreen(
        genres: [],
        latitude: 0.0,
        longitude: 0.0,
        fetchRecommended: (genres) async => [], // Mock function returns empty list
      ),
    ));
    
    // The FutureBuilder needs to complete.
    await tester.pumpAndSettle(); // Wait for the FutureBuilder to resolve.

    // Verify AppBar title and new background color.
    final AppBar appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.title is Text, isTrue);
    expect((appBar.title as Text).data, 'あなたへのおすすめ');
    expect(appBar.backgroundColor, Colors.blueGrey[700]);
    
    // Test for the "empty recommendations" text.
    expect(find.text("条件に合うおすすめ店舗が見つかりませんでした"), findsOneWidget);
    final Text emptyText = tester.widget(find.text("条件に合うおすすめ店舗が見つかりませんでした"));
    expect(emptyText.style?.color, Colors.grey[800]);
  });
}
