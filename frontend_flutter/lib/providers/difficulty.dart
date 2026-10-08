/// 短文难度。apiValue 与后端 /learn/compose 的 difficulty 取值一致。
/// 界面文字见 lib/l10n/l10n.dart 的 difficultyLabel()。
enum Difficulty {
  beginner('beginner'),
  intermediate('intermediate'),
  advanced('advanced');

  const Difficulty(this.apiValue);

  final String apiValue;

  /// 每次启动的默认难度（不跨会话记住）。
  static const defaultValue = Difficulty.intermediate;
}
