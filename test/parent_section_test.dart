import 'package:chihchi/features/parent/parent_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Parent Zone list rows show their tap ripple (no hidden-ink warning)', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ParentSection(children: [ListTile(title: const Text('Row'), onTap: () {})]),
      ),
    ));
    await tester.tap(find.text('Row'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
