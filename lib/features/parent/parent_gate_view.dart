import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import 'parent_components.dart';
import 'parent_text.dart';

/// A simple addition question that keeps young children out of the Parent Zone. A new question is
/// made for every attempt; only the two numbers are kept.
class ParentGateChallenge {
  const ParentGateChallenge(this.lhs, this.rhs);
  final int lhs, rhs;

  /// Sums from 9 to 21, so the answer is usually two digits.
  static ParentGateChallenge random([math.Random? r]) {
    final g = r ?? math.Random();
    return ParentGateChallenge(5 + g.nextInt(8), 4 + g.nextInt(6));
  }

  bool accepts(String input) => int.tryParse(input.trim()) == lhs + rhs;

  @override
  bool operator ==(Object other) => other is ParentGateChallenge && other.lhs == lhs && other.rhs == rhs;
  @override
  int get hashCode => Object.hash(lhs, rhs);
}

/// Temporary parent access. It lives only while the Parent Zone is open, is cleared on exit, and
/// locks again if the app spends too long in the background.
class ParentSession extends ChangeNotifier {
  static const backgroundTimeout = Duration(seconds: 120);

  bool isUnlocked = false;
  DateTime? _backgroundedAt;

  void unlock() {
    isUnlocked = true;
    _backgroundedAt = null;
    notifyListeners();
  }

  void lock() {
    isUnlocked = false;
    _backgroundedAt = null;
    notifyListeners();
  }

  void appDidLeaveForeground([DateTime? at]) {
    if (!isUnlocked || _backgroundedAt != null) return;
    _backgroundedAt = at ?? DateTime.now();
  }

  void appDidBecomeActive([DateTime? at]) {
    final since = _backgroundedAt;
    _backgroundedAt = null;
    if (since == null) return;
    if ((at ?? DateTime.now()).difference(since) >= backgroundTimeout) lock();
  }
}

/// Asks a simple addition question before opening the Parent Zone.
class ParentGateView extends StatefulWidget {
  const ParentGateView({super.key, required this.onSuccess, required this.onClose});
  final VoidCallback onSuccess;
  final VoidCallback onClose;

  @override
  State<ParentGateView> createState() => _ParentGateViewState();
}

class _ParentGateViewState extends State<ParentGateView> {
  var _challenge = ParentGateChallenge.random();
  final _answer = TextEditingController();
  final _focus = FocusNode();
  bool _wrong = false;

  @override
  void initState() {
    super.initState();
    _answer.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _answer.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _answer.text.trim();
    if (text.isEmpty) return;
    if (_challenge.accepts(text)) {
      _answer.clear();
      widget.onSuccess();
    } else {
      _focus.unfocus();
      setState(() => _wrong = true);
      final language = context.read<AppState>().language;
      SemanticsService.sendAnnouncement(
          View.of(context), ParentText.notQuiteRight.resolve(language), Directionality.of(context));
    }
  }

  void _newQuestion() {
    var next = ParentGateChallenge.random();
    while (next == _challenge) {
      next = ParentGateChallenge.random();
    }
    setState(() {
      _challenge = next;
      _answer.clear();
      _wrong = false;
    });
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<AppState>().language;
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: parentBackground(context),
      appBar: AppBar(
        backgroundColor: parentBackground(context),
        automaticallyImplyLeading: false,
        actions: [TextButton(onPressed: widget.onClose, child: Text(ParentText.close.resolve(language)))],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(children: [
              Semantics(
                header: true,
                child: Column(children: [
                  Icon(Icons.shield_outlined, size: 44, color: theme.colorScheme.primary),
                  const SizedBox(height: 8),
                  Text(ParentText.parentZone.resolve(language),
                      textAlign: TextAlign.center, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                  Text(ParentText.forParents.resolve(language),
                      textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: secondaryText(context))),
                ]),
              ),
              const SizedBox(height: 24),
              if (_wrong) ...[
                Text(ParentText.notQuiteRight.resolve(language), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(onPressed: _newQuestion, child: Text(ParentText.tryAgain.resolve(language))),
                ),
              ] else ...[
                Text(ParentText.pleaseSolve.resolve(language), style: theme.textTheme.titleMedium),
                const SizedBox(height: 16),
                Semantics(
                  label: ParentText.gateQuestion(_challenge.lhs, _challenge.rhs).resolve(language),
                  excludeSemantics: true,
                  child: Text('${_challenge.lhs} + ${_challenge.rhs} = ?',
                      style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w600, fontFeatures: const [FontFeature.tabularFigures()])),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _answer,
                  focusNode: _focus,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    hintText: ParentText.answer.resolve(language),
                    filled: true,
                    fillColor: parentCardColor(context),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: _answer.text.trim().isEmpty ? null : _submit,
                    child: Text(ParentText.continueButton.resolve(language)),
                  ),
                ),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}
