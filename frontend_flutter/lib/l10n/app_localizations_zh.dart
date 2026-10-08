// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'AI 英语学习';

  @override
  String get commonCancel => '取消';

  @override
  String get commonRetry => '重试';

  @override
  String get commonBack => '返回';

  @override
  String get commonDelete => '删除';

  @override
  String get tabHome => '首页';

  @override
  String get tabHistory => '历史';

  @override
  String get accountMenu => '账户';

  @override
  String get accountChangePassword => '修改密码';

  @override
  String get accountLogout => '登出';

  @override
  String get logoutDialogTitle => '确定要登出吗？';

  @override
  String get logoutDialogConfirm => '登出';

  @override
  String get difficultyLabel => '短文难度';

  @override
  String get difficultyBeginner => '初级';

  @override
  String get difficultyIntermediate => '中级';

  @override
  String get difficultyAdvanced => '高级';

  @override
  String get errorGeneric => '出了点问题，请重试。';

  @override
  String get errorTimeout => '请求超时，请重试。';

  @override
  String get errorNetwork => '无法连接服务器，请检查网络。';

  @override
  String errorServer(int status) {
    return '服务器出错（$status），请稍后再试。';
  }

  @override
  String get errorInvalidRequest => '请求参数有误。';

  @override
  String rateLimitedCountdown(String time) {
    return '$time 后可再试';
  }

  @override
  String get startupErrorTitle => '无法连接服务器，请检查网络。';

  @override
  String get startupErrorLogout => '退出登录';

  @override
  String get degradedOcrUnavailable => '识别服务不可用。以下是示例单词，不是从你的照片中识别的。';

  @override
  String get degradedOcrMock => '识别处于模拟模式。以下是示例单词，不是从你的照片中识别的。';

  @override
  String get degradedAiNotConfigured => 'AI 服务未配置。这是一篇示例短文，不是根据你的单词写的。';

  @override
  String get degradedAi => 'AI 服务不可用。这是一篇示例短文，不是根据你的单词写的。';

  @override
  String get degradedOther => '部分结果是示例数据，不是根据你的输入生成的。';

  @override
  String degradedReason(String reason) {
    return '原因：$reason';
  }

  @override
  String get degradedSavedRecord => '这是一篇示例短文，不是根据你的单词写的。';

  @override
  String get loginTitle => '登录';

  @override
  String get usernameLabel => '用户名';

  @override
  String get usernameHint => '请输入用户名';

  @override
  String get passwordLabel => '密码';

  @override
  String get passwordHint => '请输入密码';

  @override
  String get passwordVisibilityToggle => '显示或隐藏密码';

  @override
  String get loginButton => '登录';

  @override
  String get loginNoAccount => '还没有账号？';

  @override
  String get loginGoRegister => '注册';

  @override
  String get loginForgotPassword => '忘记密码？请联系管理员重置。';

  @override
  String get loginEmptyFields => '请输入用户名和密码';

  @override
  String get loginSessionExpired => '登录已失效，请重新登录。';

  @override
  String get registerTitle => '注册';

  @override
  String get usernameRule => '3–20 位字母、数字或下划线';

  @override
  String get passwordRule => '至少 8 位';

  @override
  String get confirmPasswordLabel => '确认密码';

  @override
  String get confirmPasswordHint => '请再次输入密码';

  @override
  String get registerButton => '注册';

  @override
  String get registerHaveAccount => '已有账号？';

  @override
  String get registerGoLogin => '登录';

  @override
  String get validationUsernameRequired => '请输入用户名';

  @override
  String get validationUsernameInvalid => '用户名需为 3–20 位字母、数字或下划线';

  @override
  String get validationPasswordRequired => '请输入密码';

  @override
  String get validationPasswordTooShort => '密码至少 8 位';

  @override
  String get validationPasswordTooLong => '密码不能超过 128 位';

  @override
  String get validationPasswordSameAsUsername => '密码不能与用户名相同';

  @override
  String get validationPasswordMismatch => '两次输入的密码不一致';

  @override
  String get changePasswordTitle => '修改密码';

  @override
  String changePasswordAccount(String username) {
    return '当前账号：$username';
  }

  @override
  String get changePasswordCardTitle => '设置新密码';

  @override
  String get currentPasswordLabel => '当前密码';

  @override
  String get currentPasswordHint => '请输入当前密码';

  @override
  String get validationCurrentPasswordRequired => '请输入当前密码';

  @override
  String get newPasswordLabel => '新密码';

  @override
  String get newPasswordHint => '请输入新密码';

  @override
  String get confirmNewPasswordLabel => '确认新密码';

  @override
  String get confirmNewPasswordHint => '请再次输入新密码';

  @override
  String get validationNewPasswordSameAsCurrent => '新密码不能与当前密码相同';

  @override
  String get changePasswordSave => '保存';

  @override
  String get changePasswordSuccess => '密码已修改。';

  @override
  String get securityTipTitle => '安全小贴士';

  @override
  String get securityTipBody => '修改后，其他设备上的登录会失效，需要重新登录。忘记当前密码请联系管理员重置。';

  @override
  String get homeHeadline => '用 AI 学英语';

  @override
  String get homeSubtitle => '上传一张照片，提取英文单词，\n并生成学习材料';

  @override
  String get homeGallery => '从相册上传';

  @override
  String get homeGallerySubtitle => '选一张课本、单词表或试卷的照片';

  @override
  String get homeCamera => '拍照';

  @override
  String get homeCameraSubtitle => '直接拍摄书本或试卷';

  @override
  String get homeTipTitle => '学习小贴士';

  @override
  String get homeTipBody => '拍课本、单词表或试卷都可以。识别出单词后，可以先挑选，再生成短文和填空练习。';

  @override
  String get ocrTitle => '正在识别';

  @override
  String get ocrRecognizing => '正在识别照片中的单词…';

  @override
  String get ocrRecognizingHint => '通常需要几秒钟';

  @override
  String get ocrFailedTitle => '识别失败';

  @override
  String get ocrFailedTip => '拍得清晰、光线充足时更容易识别。';

  @override
  String get ocrRepick => '重新选图';

  @override
  String get ocrRetry => '重试';

  @override
  String get ocrNetworkTitle => '无法连接服务器';

  @override
  String get ocrNetworkBody => '请检查网络后重试。';

  @override
  String get ocrBackHome => '返回首页';

  @override
  String get confirmTitle => '确认单词';

  @override
  String get confirmTipTitle => '点击单词可选中或取消';

  @override
  String get confirmTipBody => '只有选中的单词会用来写短文和练习。';

  @override
  String confirmSelectedCount(int count, int max) {
    return '已选 $count / $max';
  }

  @override
  String get confirmSelectAll => '全选';

  @override
  String get confirmClearSelection => '清空';

  @override
  String get confirmEmpty => '没有识别出单词，可以在下方手动添加。';

  @override
  String get confirmAddHint => '添加单词';

  @override
  String get confirmAddButton => '添加';

  @override
  String confirmDeleteWord(String word) {
    return '删除 $word';
  }

  @override
  String get confirmGenerate => '生成';

  @override
  String get confirmRegenerate => '重新生成';

  @override
  String get confirmGenerating => '正在写短文和练习题…';

  @override
  String confirmGenerateFailed(String reason) {
    return '生成失败：$reason';
  }

  @override
  String confirmTooManyWords(int max) {
    return '一次最多 $max 个单词，请取消一些';
  }

  @override
  String get addWordEmpty => '请先输入单词';

  @override
  String get addWordNoLetter => '单词至少要包含一个字母';

  @override
  String get addWordDuplicate => '这个单词已经在列表里了';

  @override
  String addWordTooLong(int max) {
    return '单词不能超过 $max 个字符';
  }

  @override
  String get storyTitle => '学习结果';

  @override
  String get detailTitle => '学习记录';

  @override
  String recordMeta(int count, String difficulty) {
    return '$count 个单词 · $difficulty';
  }

  @override
  String get sectionWords => '本次单词';

  @override
  String get sectionEnglishStory => '英文短文';

  @override
  String get sectionChineseTranslation => '中文翻译';

  @override
  String get sectionEnglishBlank => '英文填空';

  @override
  String get sectionChineseBlank => '中文填空';

  @override
  String get englishBlankHint => '根据记忆填出横线处的单词。';

  @override
  String get chineseBlankHint => '根据中文意思，填出横线处的中文和对应的英文单词。';

  @override
  String get storyBackToEdit => '返回修改单词';

  @override
  String get saveButton => '保存';

  @override
  String get saveButtonSaving => '保存中';

  @override
  String get saveButtonSaved => '已保存';

  @override
  String get saveSuccess => '已保存。';

  @override
  String saveFailed(String reason) {
    return '保存失败：$reason';
  }

  @override
  String get storyNoData => '暂无数据';

  @override
  String detailTime(DateTime time) {
    final intl.DateFormat timeDateFormat = intl.DateFormat(
      'y年M月d日 HH:mm',
      localeName,
    );
    final String timeString = timeDateFormat.format(time);

    return '$timeString';
  }

  @override
  String get exportPdf => '导出 PDF';

  @override
  String get exportPdfInProgress => '正在导出…';

  @override
  String get exportPdfFailed => '导出 PDF 失败，请重试。';

  @override
  String get historyTitle => '历史记录';

  @override
  String historyTotal(int total) {
    return '共 $total 条';
  }

  @override
  String get historySearchHint => '搜索单词或英文短文';

  @override
  String get historySearchClear => '清空搜索';

  @override
  String get historySearchTip => '只能搜索英文单词或短语';

  @override
  String historyCardTime(DateTime time) {
    final intl.DateFormat timeDateFormat = intl.DateFormat(
      'M月d日 HH:mm',
      localeName,
    );
    final String timeString = timeDateFormat.format(time);

    return '$timeString';
  }

  @override
  String historyCardMeta(String difficulty, int count) {
    return '$difficulty · $count 词';
  }

  @override
  String historyCardMoreWords(int count) {
    return '+$count';
  }

  @override
  String get historyCardViewDetail => '查看详情';

  @override
  String get historyDeleteTooltip => '删除记录';

  @override
  String historyLoadMore(int loaded, int total) {
    return '加载更多（$loaded / $total）';
  }

  @override
  String get historyLoadingMore => '正在加载…';

  @override
  String historyAllLoaded(int total) {
    return '已显示全部 $total 条记录';
  }

  @override
  String get historyEmptyTitle => '还没有记录';

  @override
  String get historyEmptyBody => '拍一张照片，开始第一次学习。';

  @override
  String get historyEmptyAction => '去拍照';

  @override
  String historyNoMatch(String query) {
    return '没有匹配“$query”的记录';
  }

  @override
  String get deleteDialogTitle => '删除这条记录？';

  @override
  String get deleteDialogBody => '删除后无法恢复。';

  @override
  String deleteDialogWords(String words, int count) {
    return '包含 $words 等 $count 个单词';
  }

  @override
  String get deleteDialogConfirm => '删除';

  @override
  String get historyDeleted => '已删除。';

  @override
  String historyLoadFailed(String reason) {
    return '加载记录失败：$reason';
  }

  @override
  String historyLoadMoreFailed(String reason) {
    return '加载更多失败：$reason';
  }

  @override
  String historyDeleteFailed(String reason) {
    return '删除记录失败：$reason';
  }

  @override
  String get pdfTitle => '英语学习记录';

  @override
  String pdfDate(DateTime time) {
    final intl.DateFormat timeDateFormat = intl.DateFormat(
      'y年M月d日 HH:mm',
      localeName,
    );
    final String timeString = timeDateFormat.format(time);

    return '日期：$timeString';
  }
}
