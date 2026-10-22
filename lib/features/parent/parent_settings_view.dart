import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/store/entitlement_manager.dart';
import '../../data/storage/player_progress.dart';
import '../../domain/models/app_language.dart';
import '../../services/audio/child_name_voice.dart';
import '../../services/audio/music_synthesizer.dart';
import '../../services/progress/progress_service.dart';
import '../character/avatar_appearance.dart';
import '../character/character_studio_view.dart';
import '../character/character_text.dart';
import '../character/player_character_store.dart';
import '../common/name_voice_record_button.dart';
import '../store/full_adventure_unlock_flow.dart';
import '../store/store_text.dart';
import 'parent_components.dart';
import 'parent_controls_view.dart';
import 'parent_privacy_view.dart';
import 'parent_statistics.dart';
import 'parent_text.dart';

/// Opens the character studio for the child who is playing.
void openCharacterStudio(BuildContext context) {
  final store = context.read<PlayerCharacterStore>();
  final progress = context.read<ProgressService>();
  Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (context) => CharacterStudioView(
      mode: StudioMode.editing,
      start: store.hasCharacter ? store.appearance : AvatarAppearance.starter(progress.progress.childGender),
      onClose: () => Navigator.of(context).pop(),
    ),
  ));
}

/// Parent-only settings hub.
class ParentSettingsView extends StatelessWidget {
  const ParentSettingsView({super.key, required this.viewModel});
  final ParentDashboardViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final language = context.watch<AppState>().language;
    final entitlements = context.watch<EntitlementManager>();
    void push(Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    Widget link(IconData icon, String title, VoidCallback onTap, {Widget? trailing, Color? color}) => ListTile(
          leading: Icon(icon, color: color ?? Theme.of(context).colorScheme.primary),
          title: Text(title, style: TextStyle(color: color)),
          trailing: trailing ?? const Icon(Icons.chevron_right),
          onTap: onTap,
        );
    return ParentPage(title: ParentText.parentSettings.resolve(language), children: [
      ParentSection(
        footer: (entitlements.isPremium ? StoreText.unlockedHere : StoreText.freeVersion).resolve(language),
        children: [
          link(Icons.workspace_premium, StoreText.title.resolve(language), () => push(const FullAdventureView()),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                if (entitlements.isPremium) const Icon(Icons.verified, color: Colors.green),
                const Icon(Icons.chevron_right),
              ])),
        ],
      ),
      ParentSection(header: ParentText.general.resolve(language), children: [
        link(Icons.people, ParentText.children.resolve(language), () => push(ChildrenView(onChanged: viewModel.refresh))),
        link(Icons.account_circle, ParentText.childProfile.resolve(language),
            () => push(ChildProfileView(onSaved: viewModel.refresh))),
        link(Icons.child_care, ParentText.editCharacter.resolve(language), () => openCharacterStudio(context),
            trailing: const SizedBox.shrink()),
        link(Icons.music_note, ParentText.backgroundMusic.resolve(language), () => push(const MusicPickerView())),
        link(Icons.tune, ParentText.parentControls.resolve(language), () => push(const ParentControlsView())),
      ]),
      ParentSection(header: ParentText.privacy.resolve(language), children: [
        link(Icons.back_hand, ParentText.privacyTitle.resolve(language), () => push(const ParentPrivacyView())),
        link(Icons.restart_alt, ParentText.resetTitle.resolve(language), () => push(ResetProgressView(onReset: viewModel.refresh)),
            color: Colors.red),
      ]),
      ParentSection(header: ParentText.support.resolve(language), children: [
        link(Icons.favorite_border, ParentText.supportTitle.resolve(language), () => push(const SupportChihChiView())),
      ]),
      ParentSection(header: ParentText.about.resolve(language), children: [
        link(Icons.info_outline, ParentText.aboutTitle.resolve(language), () => push(const AboutChihChiView())),
      ]),
    ]);
  }
}

String _nameOf(PlayerProgress child, AppLanguage language) =>
    child.childName.isEmpty ? ParentText.nicknamePlaceholder.resolve(language) : child.childName;

/// Every child on this device: switch who is playing, add a child, or delete one.
class ChildrenView extends StatelessWidget {
  const ChildrenView({super.key, required this.onChanged});
  final VoidCallback onChanged;

  Future<void> _add(BuildContext context, AppLanguage language) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(ParentText.addChild.resolve(language)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(ParentText.addChildPrompt.resolve(language)),
          TextField(
            controller: controller,
            autofocus: true,
            maxLength: 20,
            textCapitalization: TextCapitalization.words,
            autocorrect: false,
            decoration: InputDecoration(hintText: ParentText.nicknamePlaceholder.resolve(language)),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(ParentText.cancel.resolve(language))),
          TextButton(onPressed: () => Navigator.pop(context, controller.text), child: Text(ParentText.save.resolve(language))),
        ],
      ),
    );
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty || !context.mounted) return;
    context.read<ProgressService>().addProfile(trimmed.length > 20 ? trimmed.substring(0, 20) : trimmed);
    onChanged();
  }

  Future<void> _delete(BuildContext context, AppLanguage language, PlayerProgress child) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(ParentText.deleteChildQuestion(_nameOf(child, language)).resolve(language)),
        content: Text(ParentText.deleteChildMessage.resolve(language)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(ParentText.cancel.resolve(language))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(ParentText.deleteChild.resolve(language)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    context.read<ProgressService>().deleteProfile(child.profileID);
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<AppState>().language;
    final progress = context.watch<ProgressService>();
    return ParentPage(title: ParentText.children.resolve(language), children: [
      ParentSection(footer: ParentText.childrenFooter.resolve(language), children: [
        for (final child in progress.profiles)
          Semantics(
            selected: child.profileID == progress.activeProfileID,
            child: ListTile(
              leading: Text(child.childAvatar.isEmpty ? '🐼' : child.childAvatar, style: const TextStyle(fontSize: 26)),
              title: Text(_nameOf(child, language), style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: child.profileID == progress.activeProfileID ? Text(ParentText.playingNow.resolve(language)) : null,
              onTap: () {
                progress.switchProfile(child.profileID);
                onChanged();
              },
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                if (child.profileID == progress.activeProfileID)
                  Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary),
                if (progress.profiles.length > 1)
                  IconButton(
                    tooltip: ParentText.deleteChild.resolve(language),
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _delete(context, language, child),
                  ),
              ]),
            ),
          ),
      ]),
      if (progress.canAddProfile)
        ParentSection(children: [
          ListTile(
            leading: Icon(Icons.add_circle, color: Theme.of(context).colorScheme.primary),
            title: Text(ParentText.addChild.resolve(language), style: TextStyle(color: Theme.of(context).colorScheme.primary)),
            onTap: () => _add(context, language),
          ),
        ]),
    ]);
  }
}

/// Ten background tunes: tap one to hear it and make it the tune every game plays.
class MusicPickerView extends StatefulWidget {
  const MusicPickerView({super.key});

  @override
  State<MusicPickerView> createState() => _MusicPickerViewState();
}

class _MusicPickerViewState extends State<MusicPickerView> {
  late final AppState _appState = context.read<AppState>();

  @override
  void dispose() {
    _appState.audioService.endMusicPreview();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<AppState>().language;
    final audio = _appState.audioService;
    return ListenableBuilder(
      listenable: audio,
      builder: (context, _) => ParentPage(title: ParentText.backgroundMusic.resolve(language), children: [
        ParentSection(footer: ParentText.backgroundMusicFooter.resolve(language), children: [
          for (final track in GameMusicTrack.values)
            Semantics(
              selected: audio.musicTrack == track,
              child: ListTile(
                leading: Text(track.emoji, style: const TextStyle(fontSize: 26)),
                title: Text(track.title(language)),
                trailing: audio.musicTrack == track
                    ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
                    : null,
                onTap: () {
                  audio.previewMusic(track);
                  context.read<ProgressService>().setGameMusicTrack(track);
                },
              ),
            ),
        ]),
      ]),
    );
  }
}

/// Local nickname, avatar and the child's recorded name. No personal details are asked for.
class ChildProfileView extends StatefulWidget {
  const ChildProfileView({super.key, required this.onSaved});
  final VoidCallback onSaved;

  static const avatars = ['🐼', '🦊', '🐯', '🐰', '🐨', '🦁', '🐸'];

  @override
  State<ChildProfileView> createState() => _ChildProfileViewState();
}

class _ChildProfileViewState extends State<ChildProfileView> {
  final _nickname = TextEditingController();
  String _avatar = '';
  ChildGender? _gender;
  final _recorder = ChildNameVoiceRecorder();
  bool _hasSavedVoice = false;
  bool _removesSavedVoice = false;

  bool get _hasNewRecording => _recorder.state == NameRecorderState.recorded;
  bool get _keepsSavedVoice => _hasSavedVoice && !_removesSavedVoice;
  bool get _canSave => _nickname.text.trim().isNotEmpty || _hasNewRecording || _keepsSavedVoice;

  @override
  void initState() {
    super.initState();
    final p = context.read<ProgressService>().progress;
    _nickname.text = p.childName;
    _avatar = p.childAvatar;
    _gender = p.childGender;
    _hasSavedVoice = ChildNameVoice.hasSavedVoice();
    _nickname.addListener(() => setState(() {}));
    _recorder.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _recorder.stopEverything();
    _recorder.dispose();
    _nickname.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_hasNewRecording) {
      try {
        await _recorder.saveDraft();
      } catch (_) {}
    } else if (_removesSavedVoice) {
      await ChildNameVoice.delete();
    }
    if (!mounted) return;
    final progress = context.read<ProgressService>();
    progress.updateChildProfile(_nickname.text.trim(), _avatar);
    progress.setChildGender(_gender);
    widget.onSaved();
    Navigator.of(context).pop();
  }

  String _voiceStatus(AppLanguage language) {
    if (_hasNewRecording) return ParentText.nameVoiceNew.resolve(language);
    if (_keepsSavedVoice) return ParentText.nameVoiceSaved.resolve(language);
    return ParentText.noNameVoice.resolve(language);
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<AppState>().language;
    final primary = Theme.of(context).colorScheme.primary;
    return ParentPage(
      title: ParentText.childProfile.resolve(language),
      actions: [TextButton(onPressed: _canSave ? _save : null, child: Text(ParentText.save.resolve(language)))],
      children: [
        ParentSection(
          header: ParentText.nickname.resolve(language),
          footer: ParentText.nicknameFooter.resolve(language),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _nickname,
                maxLength: 20,
                textCapitalization: TextCapitalization.words,
                autocorrect: false,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  counterText: '',
                  hintText: ParentText.nicknamePlaceholder.resolve(language),
                ),
              ),
            ),
          ],
        ),
        ParentSection(header: CharacterText.boyOrGirl.resolve(language), children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<ChildGender?>(
              segments: [
                const ButtonSegment(value: null, label: Text('—')),
                ButtonSegment(value: ChildGender.boy, label: Text('👦 ${CharacterText.boy.resolve(language)}')),
                ButtonSegment(value: ChildGender.girl, label: Text('👧 ${CharacterText.girl.resolve(language)}')),
              ],
              selected: {_gender},
              onSelectionChanged: (s) => setState(() => _gender = s.first),
            ),
          ),
        ]),
        ParentSection(
          header: ParentText.nameVoice.resolve(language),
          footer: ParentText.nameVoiceFooter.resolve(language),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(children: [
                SizedBox(
                  width: 110,
                  child: NameVoiceRecordButton(
                    recorder: _recorder,
                    title: ParentText.holdToRecord.resolve(language),
                    recordingTitle: ParentText.recordingNow.resolve(language),
                    size: 64,
                    titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_voiceStatus(language), style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (_hasNewRecording || _keepsSavedVoice)
                      TextButton.icon(
                        onPressed: () => _hasNewRecording ? _recorder.playDraft() : _recorder.playSaved(),
                        icon: const Icon(Icons.play_circle),
                        label: Text(ParentText.play.resolve(language)),
                      ),
                  ]),
                ),
              ]),
            ),
            if (_recorder.state == NameRecorderState.microphoneDenied)
              ListTile(
                leading: const Icon(Icons.mic_off, color: Colors.orange),
                title: Text(ParentPlatformText.micDenied.resolve(language), style: const TextStyle(fontSize: 13, color: Colors.orange)),
              ),
            if (_hasNewRecording || _keepsSavedVoice)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: Text(ParentText.deleteRecording.resolve(language), style: const TextStyle(color: Colors.red)),
                onTap: () {
                  _recorder.discardDraft();
                  setState(() => _removesSavedVoice = _hasSavedVoice);
                },
              ),
          ],
        ),
        const ChildCharacterSection(),
        ParentSection(header: ParentText.avatar.resolve(language), children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(spacing: 12, runSpacing: 12, children: [
              for (final option in ChildProfileView.avatars)
                Semantics(
                  button: true,
                  selected: _avatar == option,
                  label: option,
                  child: GestureDetector(
                    onTap: () => setState(() => _avatar = option),
                    child: Container(
                      width: 52,
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _avatar == option ? primary.withValues(alpha: 0.2) : Colors.transparent,
                        border: Border.all(color: _avatar == option ? primary : Colors.transparent, width: 2),
                      ),
                      child: Text(option, style: const TextStyle(fontSize: 32)),
                    ),
                  ),
                ),
            ]),
          ),
        ]),
      ],
    );
  }
}

/// The child's own character: see it, or delete it (ChihChi becomes the hero again).
class ChildCharacterSection extends StatelessWidget {
  const ChildCharacterSection({super.key});

  @override
  Widget build(BuildContext context) {
    final language = context.watch<AppState>().language;
    final store = context.watch<PlayerCharacterStore>();
    return ParentSection(
      header: ParentText.childCharacter.resolve(language),
      footer: ParentText.characterFooter.resolve(language),
      children: store.hasCharacter
          ? [
              ListTile(
                leading: store.portrait == null
                    ? null
                    : ClipOval(child: Image.memory(store.portrait!, width: 64, height: 64, fit: BoxFit.contain)),
                title: Text(
                  store.isEnabled ? CharacterText.myCharacter.resolve(language) : CharacterText.playingAsChihChi.resolve(language),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: Text(ParentText.deleteCharacter.resolve(language), style: const TextStyle(color: Colors.red)),
                onTap: () async {
                  final yes = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(ParentText.characterDeleteQuestion.resolve(language)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(ParentText.cancel.resolve(language))),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                          child: Text(ParentText.deleteCharacter.resolve(language)),
                        ),
                      ],
                    ),
                  );
                  if (yes == true) store.deleteEverything();
                },
              ),
            ]
          : [
              ListTile(title: Text(ParentText.characterNone.resolve(language), style: TextStyle(color: secondaryText(context)))),
            ],
    );
  }
}
