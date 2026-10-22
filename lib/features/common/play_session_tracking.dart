import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../domain/models/home_game.dart';
import '../../services/progress/progress_service.dart';

/// Times a game screen for the Parent Zone's activity history. The clock only runs while the
/// screen is shown and the app is active; the game itself is unaware of it.
class PlaySessionTracking extends StatefulWidget {
  const PlaySessionTracking({super.key, required this.game, required this.child});
  final HomeGame game;
  final Widget child;

  @override
  State<PlaySessionTracking> createState() => _PlaySessionTrackingState();
}

class _PlaySessionTrackingState extends State<PlaySessionTracking> with WidgetsBindingObserver {
  late final ProgressService _progress;

  @override
  void initState() {
    super.initState();
    _progress = context.read<ProgressService>();
    WidgetsBinding.instance.addObserver(this);
    _progress.beginPlaySession(widget.game);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _progress.resumePlaySession();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _progress.pausePlaySession();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _progress.endPlaySession();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
