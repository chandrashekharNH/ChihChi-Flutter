import 'package:flutter/material.dart';

import '../../core/ui/kid_text.dart';
import '../../services/audio/child_name_voice.dart';

/// Big microphone: hold it and say your name, let go to stop.
class NameVoiceRecordButton extends StatelessWidget {
  const NameVoiceRecordButton({
    super.key,
    required this.recorder,
    required this.title,
    required this.recordingTitle,
    this.size = 132,
    this.titleStyle,
  });

  final ChildNameVoiceRecorder recorder;
  final String title;
  final String recordingTitle;
  final double size;
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: recorder,
      builder: (context, _) {
        final isRecording = recorder.state == NameRecorderState.recording;
        return Semantics(
          button: true,
          label: isRecording ? recordingTitle : title,
          onTap: () => isRecording ? recorder.stopRecording() : recorder.startRecording(),
          excludeSemantics: true,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Listener(
              onPointerDown: (_) => recorder.startRecording(),
              onPointerUp: (_) => recorder.stopRecording(),
              onPointerCancel: (_) => recorder.stopRecording(),
              child: SizedBox(
                child: SizedBox(
                  width: size + 18,
                  height: size + 18,
                  child: Stack(alignment: Alignment.center, children: [
                    if (isRecording)
                      Container(
                        width: size + 18,
                        height: size + 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.red.withValues(alpha: 0.35), width: 10),
                        ),
                      ),
                    Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isRecording ? Colors.red : Colors.white,
                        boxShadow: const [BoxShadow(color: Color(0x2E000000), blurRadius: 8, offset: Offset(0, 4))],
                      ),
                      child: Icon(Icons.mic, size: size * 0.42, color: isRecording ? Colors.white : Colors.red),
                    ),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(isRecording ? recordingTitle : title, textAlign: TextAlign.center, style: titleStyle ?? kid(17)),
          ]),
        );
      },
    );
  }
}
