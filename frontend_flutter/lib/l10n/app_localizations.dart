import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('zh')];

  /// No description provided for @appTitle.
  ///
  /// In zh, this message translates to:
  /// **'AI 英语学习'**
  String get appTitle;

  /// No description provided for @commonCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get commonCancel;

  /// No description provided for @commonRetry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get commonRetry;

  /// No description provided for @commonBack.
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get commonBack;

  /// No description provided for @commonDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get commonDelete;

  /// No description provided for @tabHome.
  ///
  /// In zh, this message translates to:
  /// **'首页'**
  String get tabHome;

  /// No description provided for @tabHistory.
  ///
  /// In zh, this message translates to:
  /// **'历史'**
  String get tabHistory;

  /// No description provided for @accountMenu.
  ///
  /// In zh, this message translates to:
  /// **'账户'**
  String get accountMenu;

  /// No description provided for @accountChangePassword.
  ///
  /// In zh, this message translates to:
  /// **'修改密码'**
  String get accountChangePassword;

  /// No description provided for @accountLogout.
  ///
  /// In zh, this message translates to:
  /// **'登出'**
  String get accountLogout;

  /// No description provided for @logoutDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'确定要登出吗？'**
  String get logoutDialogTitle;

  /// No description provided for @logoutDialogConfirm.
  ///
  /// In zh, this message translates to:
  /// **'登出'**
  String get logoutDialogConfirm;

  /// No description provided for @difficultyLabel.
  ///
  /// In zh, this message translates to:
  /// **'短文难度'**
  String get difficultyLabel;

  /// No description provided for @difficultyBeginner.
  ///
  /// In zh, this message translates to:
  /// **'初级'**
  String get difficultyBeginner;

  /// No description provided for @difficultyIntermediate.
  ///
  /// In zh, this message translates to:
  /// **'中级'**
  String get difficultyIntermediate;

  /// No description provided for @difficultyAdvanced.
  ///
  /// In zh, this message translates to:
  /// **'高级'**
  String get difficultyAdvanced;

  /// No description provided for @errorGeneric.
  ///
  /// In zh, this message translates to:
  /// **'出了点问题，请重试。'**
  String get errorGeneric;

  /// No description provided for @errorTimeout.
  ///
  /// In zh, this message translates to:
  /// **'请求超时，请重试。'**
  String get errorTimeout;

  /// No description provided for @errorNetwork.
  ///
  /// In zh, this message translates to:
  /// **'无法连接服务器，请检查网络。'**
  String get errorNetwork;

  /// No description provided for @errorServer.
  ///
  /// In zh, this message translates to:
  /// **'服务器出错（{status}），请稍后再试。'**
  String errorServer(int status);

  /// No description provided for @errorInvalidRequest.
  ///
  /// In zh, this message translates to:
  /// **'请求参数有误。'**
  String get errorInvalidRequest;

  /// 429 后提交按钮上的倒计时，time 形如 07:59
  ///
  /// In zh, this message translates to:
  /// **'{time} 后可再试'**
  String rateLimitedCountdown(String time);

  /// No description provided for @startupErrorTitle.
  ///
  /// In zh, this message translates to:
  /// **'无法连接服务器，请检查网络。'**
  String get startupErrorTitle;

  /// No description provided for @startupErrorLogout.
  ///
  /// In zh, this message translates to:
  /// **'退出登录'**
  String get startupErrorLogout;

  /// No description provided for @degradedOcrUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'识别服务不可用。以下是示例单词，不是从你的照片中识别的。'**
  String get degradedOcrUnavailable;

  /// No description provided for @degradedOcrMock.
  ///
  /// In zh, this message translates to:
  /// **'识别处于模拟模式。以下是示例单词，不是从你的照片中识别的。'**
  String get degradedOcrMock;

  /// No description provided for @degradedAiNotConfigured.
  ///
  /// In zh, this message translates to:
  /// **'AI 服务未配置。这是一篇示例短文，不是根据你的单词写的。'**
  String get degradedAiNotConfigured;

  /// No description provided for @degradedAi.
  ///
  /// In zh, this message translates to:
  /// **'AI 服务不可用。这是一篇示例短文，不是根据你的单词写的。'**
  String get degradedAi;

  /// No description provided for @degradedOther.
  ///
  /// In zh, this message translates to:
  /// **'部分结果是示例数据，不是根据你的输入生成的。'**
  String get degradedOther;

  /// No description provided for @degradedReason.
  ///
  /// In zh, this message translates to:
  /// **'原因：{reason}'**
  String degradedReason(String reason);

  /// No description provided for @degradedSavedRecord.
  ///
  /// In zh, this message translates to:
  /// **'这是一篇示例短文，不是根据你的单词写的。'**
  String get degradedSavedRecord;

  /// No description provided for @loginTitle.
  ///
  /// In zh, this message translates to:
  /// **'登录'**
  String get loginTitle;

  /// No description provided for @usernameLabel.
  ///
  /// In zh, this message translates to:
  /// **'用户名'**
  String get usernameLabel;

  /// No description provided for @usernameHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入用户名'**
  String get usernameHint;

  /// No description provided for @passwordLabel.
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get passwordLabel;

  /// No description provided for @passwordHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入密码'**
  String get passwordHint;

  /// No description provided for @passwordVisibilityToggle.
  ///
  /// In zh, this message translates to:
  /// **'显示或隐藏密码'**
  String get passwordVisibilityToggle;

  /// No description provided for @loginButton.
  ///
  /// In zh, this message translates to:
  /// **'登录'**
  String get loginButton;

  /// No description provided for @loginNoAccount.
  ///
  /// In zh, this message translates to:
  /// **'还没有账号？'**
  String get loginNoAccount;

  /// No description provided for @loginGoRegister.
  ///
  /// In zh, this message translates to:
  /// **'注册'**
  String get loginGoRegister;

  /// No description provided for @loginForgotPassword.
  ///
  /// In zh, this message translates to:
  /// **'忘记密码？请联系管理员重置。'**
  String get loginForgotPassword;

  /// No description provided for @loginEmptyFields.
  ///
  /// In zh, this message translates to:
  /// **'请输入用户名和密码'**
  String get loginEmptyFields;

  /// No description provided for @loginSessionExpired.
  ///
  /// In zh, this message translates to:
  /// **'登录已失效，请重新登录。'**
  String get loginSessionExpired;

  /// No description provided for @registerTitle.
  ///
  /// In zh, this message translates to:
  /// **'注册'**
  String get registerTitle;

  /// No description provided for @usernameRule.
  ///
  /// In zh, this message translates to:
  /// **'3–20 位字母、数字或下划线'**
  String get usernameRule;

  /// No description provided for @passwordRule.
  ///
  /// In zh, this message translates to:
  /// **'至少 8 位'**
  String get passwordRule;

  /// No description provided for @confirmPasswordLabel.
  ///
  /// In zh, this message translates to:
  /// **'确认密码'**
  String get confirmPasswordLabel;

  /// No description provided for @confirmPasswordHint.
  ///
  /// In zh, this message translates to:
  /// **'请再次输入密码'**
  String get confirmPasswordHint;

  /// No description provided for @registerButton.
  ///
  /// In zh, this message translates to:
  /// **'注册'**
  String get registerButton;

  /// No description provided for @registerHaveAccount.
  ///
  /// In zh, this message translates to:
  /// **'已有账号？'**
  String get registerHaveAccount;

  /// No description provided for @registerGoLogin.
  ///
  /// In zh, this message translates to:
  /// **'登录'**
  String get registerGoLogin;

  /// No description provided for @validationUsernameRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入用户名'**
  String get validationUsernameRequired;

  /// No description provided for @validationUsernameInvalid.
  ///
  /// In zh, this message translates to:
  /// **'用户名需为 3–20 位字母、数字或下划线'**
  String get validationUsernameInvalid;

  /// No description provided for @validationPasswordRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入密码'**
  String get validationPasswordRequired;

  /// No description provided for @validationPasswordTooShort.
  ///
  /// In zh, this message translates to:
  /// **'密码至少 8 位'**
  String get validationPasswordTooShort;

  /// No description provided for @validationPasswordTooLong.
  ///
  /// In zh, this message translates to:
  /// **'密码不能超过 128 位'**
  String get validationPasswordTooLong;

  /// No description provided for @validationPasswordSameAsUsername.
  ///
  /// In zh, this message translates to:
  /// **'密码不能与用户名相同'**
  String get validationPasswordSameAsUsername;

  /// No description provided for @validationPasswordMismatch.
  ///
  /// In zh, this message translates to:
  /// **'两次输入的密码不一致'**
  String get validationPasswordMismatch;

  /// No description provided for @changePasswordTitle.
  ///
  /// In zh, this message translates to:
  /// **'修改密码'**
  String get changePasswordTitle;

  /// No description provided for @changePasswordAccount.
  ///
  /// In zh, this message translates to:
  /// **'当前账号：{username}'**
  String changePasswordAccount(String username);

  /// No description provided for @changePasswordCardTitle.
  ///
  /// In zh, this message translates to:
  /// **'设置新密码'**
  String get changePasswordCardTitle;

  /// No description provided for @currentPasswordLabel.
  ///
  /// In zh, this message translates to:
  /// **'当前密码'**
  String get currentPasswordLabel;

  /// No description provided for @currentPasswordHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入当前密码'**
  String get currentPasswordHint;

  /// No description provided for @validationCurrentPasswordRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入当前密码'**
  String get validationCurrentPasswordRequired;

  /// No description provided for @newPasswordLabel.
  ///
  /// In zh, this message translates to:
  /// **'新密码'**
  String get newPasswordLabel;

  /// No description provided for @newPasswordHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入新密码'**
  String get newPasswordHint;

  /// No description provided for @confirmNewPasswordLabel.
  ///
  /// In zh, this message translates to:
  /// **'确认新密码'**
  String get confirmNewPasswordLabel;

  /// No description provided for @confirmNewPasswordHint.
  ///
  /// In zh, this message translates to:
  /// **'请再次输入新密码'**
  String get confirmNewPasswordHint;

  /// No description provided for @validationNewPasswordSameAsCurrent.
  ///
  /// In zh, this message translates to:
  /// **'新密码不能与当前密码相同'**
  String get validationNewPasswordSameAsCurrent;

  /// No description provided for @changePasswordSave.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get changePasswordSave;

  /// No description provided for @changePasswordSuccess.
  ///
  /// In zh, this message translates to:
  /// **'密码已修改。'**
  String get changePasswordSuccess;

  /// No description provided for @securityTipTitle.
  ///
  /// In zh, this message translates to:
  /// **'安全小贴士'**
  String get securityTipTitle;

  /// No description provided for @securityTipBody.
  ///
  /// In zh, this message translates to:
  /// **'修改后，其他设备上的登录会失效，需要重新登录。忘记当前密码请联系管理员重置。'**
  String get securityTipBody;

  /// No description provided for @homeHeadline.
  ///
  /// In zh, this message translates to:
  /// **'用 AI 学英语'**
  String get homeHeadline;

  /// No description provided for @homeSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'上传一张照片，提取英文单词，\n并生成学习材料'**
  String get homeSubtitle;

  /// No description provided for @homeGallery.
  ///
  /// In zh, this message translates to:
  /// **'从相册上传'**
  String get homeGallery;

  /// No description provided for @homeGallerySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'选一张课本、单词表或试卷的照片'**
  String get homeGallerySubtitle;

  /// No description provided for @homeCamera.
  ///
  /// In zh, this message translates to:
  /// **'拍照'**
  String get homeCamera;

  /// No description provided for @homeCameraSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'直接拍摄书本或试卷'**
  String get homeCameraSubtitle;

  /// No description provided for @homeTipTitle.
  ///
  /// In zh, this message translates to:
  /// **'学习小贴士'**
  String get homeTipTitle;

  /// No description provided for @homeTipBody.
  ///
  /// In zh, this message translates to:
  /// **'拍课本、单词表或试卷都可以。识别出单词后，可以先挑选，再生成短文和填空练习。'**
  String get homeTipBody;

  /// No description provided for @ocrTitle.
  ///
  /// In zh, this message translates to:
  /// **'正在识别'**
  String get ocrTitle;

  /// No description provided for @ocrRecognizing.
  ///
  /// In zh, this message translates to:
  /// **'正在识别照片中的单词…'**
  String get ocrRecognizing;

  /// No description provided for @ocrRecognizingHint.
  ///
  /// In zh, this message translates to:
  /// **'通常需要几秒钟'**
  String get ocrRecognizingHint;

  /// No description provided for @ocrFailedTitle.
  ///
  /// In zh, this message translates to:
  /// **'识别失败'**
  String get ocrFailedTitle;

  /// No description provided for @ocrFailedTip.
  ///
  /// In zh, this message translates to:
  /// **'拍得清晰、光线充足时更容易识别。'**
  String get ocrFailedTip;

  /// No description provided for @ocrRepick.
  ///
  /// In zh, this message translates to:
  /// **'重新选图'**
  String get ocrRepick;

  /// No description provided for @ocrRetry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get ocrRetry;

  /// No description provided for @ocrNetworkTitle.
  ///
  /// In zh, this message translates to:
  /// **'无法连接服务器'**
  String get ocrNetworkTitle;

  /// No description provided for @ocrNetworkBody.
  ///
  /// In zh, this message translates to:
  /// **'请检查网络后重试。'**
  String get ocrNetworkBody;

  /// No description provided for @ocrBackHome.
  ///
  /// In zh, this message translates to:
  /// **'返回首页'**
  String get ocrBackHome;

  /// No description provided for @confirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'确认单词'**
  String get confirmTitle;

  /// No description provided for @confirmTipTitle.
  ///
  /// In zh, this message translates to:
  /// **'点击单词可选中或取消'**
  String get confirmTipTitle;

  /// No description provided for @confirmTipBody.
  ///
  /// In zh, this message translates to:
  /// **'只有选中的单词会用来写短文和练习。'**
  String get confirmTipBody;

  /// No description provided for @confirmSelectedCount.
  ///
  /// In zh, this message translates to:
  /// **'已选 {count} / {max}'**
  String confirmSelectedCount(int count, int max);

  /// No description provided for @confirmSelectAll.
  ///
  /// In zh, this message translates to:
  /// **'全选'**
  String get confirmSelectAll;

  /// No description provided for @confirmClearSelection.
  ///
  /// In zh, this message translates to:
  /// **'清空'**
  String get confirmClearSelection;

  /// No description provided for @confirmEmpty.
  ///
  /// In zh, this message translates to:
  /// **'没有识别出单词，可以在下方手动添加。'**
  String get confirmEmpty;

  /// No description provided for @confirmAddHint.
  ///
  /// In zh, this message translates to:
  /// **'添加单词'**
  String get confirmAddHint;

  /// No description provided for @confirmAddButton.
  ///
  /// In zh, this message translates to:
  /// **'添加'**
  String get confirmAddButton;

  /// No description provided for @confirmDeleteWord.
  ///
  /// In zh, this message translates to:
  /// **'删除 {word}'**
  String confirmDeleteWord(String word);

  /// No description provided for @confirmGenerate.
  ///
  /// In zh, this message translates to:
  /// **'生成'**
  String get confirmGenerate;

  /// No description provided for @confirmRegenerate.
  ///
  /// In zh, this message translates to:
  /// **'重新生成'**
  String get confirmRegenerate;

  /// No description provided for @confirmGenerating.
  ///
  /// In zh, this message translates to:
  /// **'正在写短文和练习题…'**
  String get confirmGenerating;

  /// No description provided for @confirmGenerateFailed.
  ///
  /// In zh, this message translates to:
  /// **'生成失败：{reason}'**
  String confirmGenerateFailed(String reason);

  /// No description provided for @confirmTooManyWords.
  ///
  /// In zh, this message translates to:
  /// **'一次最多 {max} 个单词，请取消一些'**
  String confirmTooManyWords(int max);

  /// No description provided for @addWordEmpty.
  ///
  /// In zh, this message translates to:
  /// **'请先输入单词'**
  String get addWordEmpty;

  /// No description provided for @addWordNoLetter.
  ///
  /// In zh, this message translates to:
  /// **'单词至少要包含一个字母'**
  String get addWordNoLetter;

  /// No description provided for @addWordDuplicate.
  ///
  /// In zh, this message translates to:
  /// **'这个单词已经在列表里了'**
  String get addWordDuplicate;

  /// No description provided for @addWordTooLong.
  ///
  /// In zh, this message translates to:
  /// **'单词不能超过 {max} 个字符'**
  String addWordTooLong(int max);

  /// No description provided for @storyTitle.
  ///
  /// In zh, this message translates to:
  /// **'学习结果'**
  String get storyTitle;

  /// No description provided for @detailTitle.
  ///
  /// In zh, this message translates to:
  /// **'学习记录'**
  String get detailTitle;

  /// No description provided for @recordMeta.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个单词 · {difficulty}'**
  String recordMeta(int count, String difficulty);

  /// No description provided for @sectionWords.
  ///
  /// In zh, this message translates to:
  /// **'本次单词'**
  String get sectionWords;

  /// No description provided for @sectionEnglishStory.
  ///
  /// In zh, this message translates to:
  /// **'英文短文'**
  String get sectionEnglishStory;

  /// No description provided for @sectionChineseTranslation.
  ///
  /// In zh, this message translates to:
  /// **'中文翻译'**
  String get sectionChineseTranslation;

  /// No description provided for @sectionEnglishBlank.
  ///
  /// In zh, this message translates to:
  /// **'英文填空'**
  String get sectionEnglishBlank;

  /// No description provided for @sectionChineseBlank.
  ///
  /// In zh, this message translates to:
  /// **'中文填空'**
  String get sectionChineseBlank;

  /// No description provided for @englishBlankHint.
  ///
  /// In zh, this message translates to:
  /// **'根据记忆填出横线处的单词。'**
  String get englishBlankHint;

  /// No description provided for @chineseBlankHint.
  ///
  /// In zh, this message translates to:
  /// **'根据中文意思，填出横线处的中文和对应的英文单词。'**
  String get chineseBlankHint;

  /// No description provided for @storyBackToEdit.
  ///
  /// In zh, this message translates to:
  /// **'返回修改单词'**
  String get storyBackToEdit;

  /// No description provided for @saveButton.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get saveButton;

  /// No description provided for @saveButtonSaving.
  ///
  /// In zh, this message translates to:
  /// **'保存中'**
  String get saveButtonSaving;

  /// No description provided for @saveButtonSaved.
  ///
  /// In zh, this message translates to:
  /// **'已保存'**
  String get saveButtonSaved;

  /// No description provided for @saveSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已保存。'**
  String get saveSuccess;

  /// No description provided for @saveFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存失败：{reason}'**
  String saveFailed(String reason);

  /// No description provided for @storyNoData.
  ///
  /// In zh, this message translates to:
  /// **'暂无数据'**
  String get storyNoData;

  /// No description provided for @detailTime.
  ///
  /// In zh, this message translates to:
  /// **'{time}'**
  String detailTime(DateTime time);

  /// No description provided for @exportPdf.
  ///
  /// In zh, this message translates to:
  /// **'导出 PDF'**
  String get exportPdf;

  /// No description provided for @exportPdfInProgress.
  ///
  /// In zh, this message translates to:
  /// **'正在导出…'**
  String get exportPdfInProgress;

  /// No description provided for @exportPdfFailed.
  ///
  /// In zh, this message translates to:
  /// **'导出 PDF 失败，请重试。'**
  String get exportPdfFailed;

  /// No description provided for @historyTitle.
  ///
  /// In zh, this message translates to:
  /// **'历史记录'**
  String get historyTitle;

  /// No description provided for @historyTotal.
  ///
  /// In zh, this message translates to:
  /// **'共 {total} 条'**
  String historyTotal(int total);

  /// No description provided for @historySearchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索单词或英文短文'**
  String get historySearchHint;

  /// No description provided for @historySearchClear.
  ///
  /// In zh, this message translates to:
  /// **'清空搜索'**
  String get historySearchClear;

  /// No description provided for @historySearchTip.
  ///
  /// In zh, this message translates to:
  /// **'只能搜索英文单词或短语'**
  String get historySearchTip;

  /// No description provided for @historyCardTime.
  ///
  /// In zh, this message translates to:
  /// **'{time}'**
  String historyCardTime(DateTime time);

  /// No description provided for @historyCardMeta.
  ///
  /// In zh, this message translates to:
  /// **'{difficulty} · {count} 词'**
  String historyCardMeta(String difficulty, int count);

  /// No description provided for @historyCardMoreWords.
  ///
  /// In zh, this message translates to:
  /// **'+{count}'**
  String historyCardMoreWords(int count);

  /// No description provided for @historyCardViewDetail.
  ///
  /// In zh, this message translates to:
  /// **'查看详情'**
  String get historyCardViewDetail;

  /// No description provided for @historyDeleteTooltip.
  ///
  /// In zh, this message translates to:
  /// **'删除记录'**
  String get historyDeleteTooltip;

  /// No description provided for @historyLoadMore.
  ///
  /// In zh, this message translates to:
  /// **'加载更多（{loaded} / {total}）'**
  String historyLoadMore(int loaded, int total);

  /// No description provided for @historyLoadingMore.
  ///
  /// In zh, this message translates to:
  /// **'正在加载…'**
  String get historyLoadingMore;

  /// No description provided for @historyAllLoaded.
  ///
  /// In zh, this message translates to:
  /// **'已显示全部 {total} 条记录'**
  String historyAllLoaded(int total);

  /// No description provided for @historyEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'还没有记录'**
  String get historyEmptyTitle;

  /// No description provided for @historyEmptyBody.
  ///
  /// In zh, this message translates to:
  /// **'拍一张照片，开始第一次学习。'**
  String get historyEmptyBody;

  /// No description provided for @historyEmptyAction.
  ///
  /// In zh, this message translates to:
  /// **'去拍照'**
  String get historyEmptyAction;

  /// No description provided for @historyNoMatch.
  ///
  /// In zh, this message translates to:
  /// **'没有匹配“{query}”的记录'**
  String historyNoMatch(String query);

  /// No description provided for @deleteDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除这条记录？'**
  String get deleteDialogTitle;

  /// No description provided for @deleteDialogBody.
  ///
  /// In zh, this message translates to:
  /// **'删除后无法恢复。'**
  String get deleteDialogBody;

  /// words 为前 3 个单词，用顿号连接
  ///
  /// In zh, this message translates to:
  /// **'包含 {words} 等 {count} 个单词'**
  String deleteDialogWords(String words, int count);

  /// No description provided for @deleteDialogConfirm.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get deleteDialogConfirm;

  /// No description provided for @historyDeleted.
  ///
  /// In zh, this message translates to:
  /// **'已删除。'**
  String get historyDeleted;

  /// No description provided for @historyLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'加载记录失败：{reason}'**
  String historyLoadFailed(String reason);

  /// No description provided for @historyLoadMoreFailed.
  ///
  /// In zh, this message translates to:
  /// **'加载更多失败：{reason}'**
  String historyLoadMoreFailed(String reason);

  /// No description provided for @historyDeleteFailed.
  ///
  /// In zh, this message translates to:
  /// **'删除记录失败：{reason}'**
  String historyDeleteFailed(String reason);

  /// No description provided for @pdfTitle.
  ///
  /// In zh, this message translates to:
  /// **'英语学习记录'**
  String get pdfTitle;

  /// No description provided for @pdfDate.
  ///
  /// In zh, this message translates to:
  /// **'日期：{time}'**
  String pdfDate(DateTime time);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
