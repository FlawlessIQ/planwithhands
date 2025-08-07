import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Focus moves to next field on Next, and validation messages appear/disappear', (
    WidgetTester tester,
  ) async {
    final formKey = GlobalKey<FormState>();
    final firstNode = FocusNode();
    final secondNode = FocusNode();
    final firstController = TextEditingController();
    final secondController = TextEditingController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            key: formKey,
            child: Column(
              children: [
                TextFormField(
                  focusNode: firstNode,
                  controller: firstController,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.sentences,
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  onFieldSubmitted:
                      (_) => FocusScope.of(tester.element(find.byType(TextFormField).first)).requestFocus(secondNode),
                ),
                TextFormField(
                  focusNode: secondNode,
                  controller: secondController,
                  textInputAction: TextInputAction.done,
                  textCapitalization: TextCapitalization.sentences,
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                ElevatedButton(onPressed: () => formKey.currentState!.validate(), child: const Text('Validate')),
              ],
            ),
          ),
        ),
      ),
    );

    // Initial: no error
    expect(find.text('Required'), findsNothing);

    // Tap validate, both show error
    await tester.tap(find.text('Validate'));
    await tester.pump();
    expect(find.text('Required'), findsNWidgets(2));

    // Enter text in first, error disappears
    await tester.enterText(find.byType(TextFormField).first, 'Hello');
    await tester.tap(find.text('Validate'));
    await tester.pump();
    expect(find.text('Required'), findsOneWidget);

    // Focus moves to next on Next
    await tester.showKeyboard(find.byType(TextFormField).first);
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    expect(secondNode.hasFocus, isTrue);
  });
}
