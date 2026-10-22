import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models/app_language.dart';
import '../../services/progress/progress_service.dart';
import 'parent_dashboard_view.dart';
import 'parent_gate_view.dart';
import 'parent_statistics.dart';
import 'parent_text.dart';

/// Root of the Parent Zone, shown full screen over the child's Home. Shows the parent gate until
/// it is solved, then the dashboard. Leaving clears the parent session.
class ParentZoneView extends StatefulWidget {
  const ParentZoneView({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const ParentZoneView()));

  @override
  State<ParentZoneView> createState() => _ParentZoneViewState();
}

class _ParentZoneViewState extends State<ParentZoneView> with WidgetsBindingObserver {
  final _session = ParentSession();
  late final ParentDashboardViewModel _viewModel = ParentDashboardViewModel(context.read<ProgressService>());
  final _navigator = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _session.addListener(() => setState(() {}));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _session.appDidBecomeActive();
    } else if (state == AppLifecycleState.paused) {
      _session.appDidLeaveForeground();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _session.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  void _exit() {
    _session.lock();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (!_session.isUnlocked) return ParentGateView(onSuccess: _session.unlock, onClose: _exit);
    // Its own navigator, so the dashboard's pages stack inside the Parent Zone.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final inner = _navigator.currentState;
        if (inner != null && inner.canPop()) {
          inner.pop();
        } else {
          _exit();
        }
      },
      child: Navigator(
        key: _navigator,
        onGenerateRoute: (_) => MaterialPageRoute(
          builder: (_) => ParentDashboardView(viewModel: _viewModel, onExit: _exit),
        ),
      ),
    );
  }
}

/// The quiet "Parent Zone" link on the child's Home screen.
class ParentZoneEntryButton extends StatelessWidget {
  const ParentZoneEntryButton({super.key, required this.language, this.showsUpdateBadge = false, required this.onTap});
  final AppLanguage language;

  /// Shows a small "Update" tag; the store link itself stays behind the parent gate.
  final bool showsUpdateBadge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${ParentText.parentZone.resolve(language)}, ${ParentText.forParents.resolve(language)}',
      value: showsUpdateBadge ? ParentText.updateAvailable.resolve(language) : '',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(12)),
          child: DefaultTextStyle.merge(
            style: const TextStyle(color: Colors.white),
            child: Row(children: [
              const Icon(Icons.lock, size: 16, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(ParentText.parentZone.resolve(language), style: const TextStyle(fontWeight: FontWeight.w600)),
                  Opacity(
                    opacity: 0.85,
                    child: Text(ParentText.forParents.resolve(language), style: const TextStyle(fontSize: 12)),
                  ),
                ]),
              ),
              if (showsUpdateBadge)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(20)),
                  child: Text(ParentText.updateBadge.resolve(language),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, size: 18, color: Colors.white),
            ]),
          ),
        ),
      ),
    );
  }
}
