import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'core/app_state.dart';
import 'core/localization/localized.dart';
import 'core/store/entitlement_manager.dart';
import 'core/store/free_uses.dart';
import 'core/store/store_manager.dart';
import 'data/game_content/language_pack.dart';
import 'domain/models/app_language.dart';
import 'features/character/character_onboarding_view.dart';
import 'features/character/character_view.dart';
import 'features/character/player_character_store.dart';
import 'features/home/home_view.dart';
import 'features/parent/parent_text.dart';
import 'services/audio/child_name_voice.dart';
import 'services/audio/kids_voice.dart';
import 'services/progress/child_profile_files.dart';
import 'services/progress/progress_service.dart';
import 'services/update/app_update_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ParentPlatformText.configure(android: Platform.isAndroid);
  PlayerCharacterStore.defaultRenderer = CharacterPortrait.render;
  await Future.wait([
    AppTextCatalog.load(),
    LanguagePack.loadAll(),
    ChildProfileFiles.load(),
    initializeDateFormatting(),
  ]);

  final progress = ProgressService();
  await progress.load();
  final appState = AppState();
  final entitlements = EntitlementManager();
  final freeUses = FreeUses();
  await Future.wait([entitlements.load(), freeUses.load(), appState.languageOrder.load(), KidsVoice.load()]);

  runApp(ChihChiApp(
    appState: appState,
    progress: progress,
    entitlements: entitlements,
    store: StoreManager(entitlements),
    freeUses: freeUses,
  ));
}

class ChihChiApp extends StatefulWidget {
  const ChihChiApp({
    super.key,
    required this.appState,
    required this.progress,
    required this.entitlements,
    required this.store,
    required this.freeUses,
  });

  final AppState appState;
  final ProgressService progress;
  final EntitlementManager entitlements;
  final StoreManager store;
  final FreeUses freeUses;

  @override
  State<ChihChiApp> createState() => _ChihChiAppState();
}

class _ChihChiAppState extends State<ChihChiApp> with WidgetsBindingObserver {
  final _updates = AppUpdateService();
  late PlayerCharacterStore _characters = PlayerCharacterStore();
  late String _activeProfile = widget.progress.activeProfileID;
  bool _needsChildName = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _configureServices();
    widget.progress.addListener(_progressChanged);
    // The store: what this account owns, plus later purchases. Works offline from the store's own
    // record; never blocks the games from starting.
    unawaited(widget.store.start());
  }

  void _configureServices() {
    final appState = widget.appState;
    final p = widget.progress.progress;
    appState.setLanguage(p.language);
    appState.setWorld(p.worldID);
    final audio = appState.audioService;
    audio.musicEnabled = p.musicEnabled;
    audio.soundEnabled = p.soundEnabled;
    audio.voiceEnabled = p.voiceEnabled;
    audio.hapticsEnabled = p.hapticsEnabled;
    audio.musicTrack = widget.progress.musicTrack;
    // First launch: ask the child's name. A recorded name counts as having a name.
    _needsChildName = p.childName.isEmpty && !ChildNameVoice.hasSavedVoice();
    // Last, so nothing above waits on the network.
    unawaited(_updates.checkForUpdate());
  }

  void _progressChanged() {
    // Another child is playing: their own character and world.
    final id = widget.progress.activeProfileID;
    if (id == _activeProfile) return;
    _activeProfile = id;
    setState(() => _characters = PlayerCharacterStore());
    widget.appState.setWorld(widget.progress.progress.worldID);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Throttled inside the service; quietly does nothing when offline.
    if (state == AppLifecycleState.resumed) unawaited(_updates.checkForUpdate());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.progress.removeListener(_progressChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.appState),
        ChangeNotifierProvider.value(value: widget.progress),
        ChangeNotifierProvider.value(value: _updates),
        ChangeNotifierProvider.value(value: _characters),
        ChangeNotifierProvider.value(value: widget.entitlements),
        ChangeNotifierProvider.value(value: widget.store),
        ChangeNotifierProvider.value(value: widget.freeUses),
      ],
      child: Consumer<AppState>(
        builder: (context, appState, _) => MaterialApp(
          title: 'ChihChi',
          debugShowCheckedModeBanner: false,
          theme: _theme(Brightness.light),
          darkTheme: _theme(Brightness.dark),
          locale: Locale(appState.language.code),
          supportedLocales: [for (final l in AppLanguage.values) Locale(l.code)],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => Directionality(
            textDirection: appState.language.isRightToLeft ? TextDirection.rtl : TextDirection.ltr,
            child: AnnotatedRegion<SystemUiOverlayStyle>(value: SystemUiOverlayStyle.light, child: child!),
          ),
          home: _needsChildName
              ? FirstLaunchFlow(onFinished: () => setState(() => _needsChildName = false))
              : const HomeView(),
        ),
      ),
    );
  }

  static ThemeData _theme(Brightness brightness) => ThemeData(
        brightness: brightness,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7A5AF8), brightness: brightness),
        useMaterial3: true,
        pageTransitionsTheme: const PageTransitionsTheme(builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        }),
      );
}
