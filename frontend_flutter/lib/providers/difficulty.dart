/// 短文难度。apiValue 与后端 /learn/compose 的 difficulty 取值一致。
enum Difficulty {
  beginner('beginner', 'Beginner'),
  intermediate('intermediate', 'Intermediate'),
  advanced('advanced', 'Advanced');

  const Difficulty(this.apiValue, this.label);

  final String apiValue;
  final String label;

  /// 每次启动的默认难度（不跨会话记住）。
  static const defaultValue = Difficulty.intermediate;
}
