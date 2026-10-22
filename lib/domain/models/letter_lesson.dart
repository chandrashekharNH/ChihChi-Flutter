class LetterLesson {
  const LetterLesson({
    required this.id,
    required this.symbol,
    required this.symbolPhoneticHint,
    required this.targetObjectID,
    required this.targetObjectName,
    required this.distractorObjectIDs,
    required this.languageCode,
  });
  final String id;
  final String symbol;
  final String symbolPhoneticHint;
  final String targetObjectID;
  final String targetObjectName;
  final List<String> distractorObjectIDs;
  final String languageCode;
}
