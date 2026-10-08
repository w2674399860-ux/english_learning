import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../providers/app_provider.dart';
import '../../theme/theme_x.dart';
import '../../widgets/hero_action_button.dart';
import '../../widgets/illustration.dart';
import '../../widgets/ink_toast.dart';
import '../../widgets/page_scaffold.dart';
import '../../widgets/tip_card.dart';
import '../auth/account_actions.dart';
import '../ocr/ocr_page.dart';

/// 首页（设计稿 ai_3）：插画、标语、"从相册上传 / 拍照"两个入口、学习小贴士。
///
/// 状态：默认；选图取消（无变化）；打开相册或相机失败（Toast）。
/// 账户菜单在顶栏右侧；底部 Tab 由 MainScreen 提供。
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final c = context.colors;
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle, style: context.text.titleLarge),
        leading: Padding(
          padding: EdgeInsets.all(tokens.spaceSm),
          child: ExcludeSemantics(
            child: Image.asset(
              IllustrationKind.mascot.asset,
              width: tokens.avatarSize,
              height: tokens.avatarSize,
            ),
          ),
        ),
        actions: const [AccountActions()],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(tokens.pageMargin),
        child: ContentWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _HomeHero(),
              SizedBox(height: tokens.spaceXl),
              Text(
                l10n.homeHeadline,
                textAlign: TextAlign.center,
                style: context.text.headlineLarge,
              ),
              SizedBox(height: tokens.spaceSm),
              Text(
                l10n.homeSubtitle,
                textAlign: TextAlign.center,
                style: context.text.bodyMedium?.copyWith(
                  color: c.onSurfaceVariant,
                ),
              ),
              SizedBox(height: tokens.spaceXl),
              HeroActionButton(
                icon: Icons.photo_library,
                title: l10n.homeGallery,
                subtitle: l10n.homeGallerySubtitle,
                onPressed: () => _pickImage(context, ImageSource.gallery),
              ),
              SizedBox(height: tokens.spaceLg),
              HeroActionButton(
                icon: Icons.photo_camera,
                title: l10n.homeCamera,
                subtitle: l10n.homeCameraSubtitle,
                lime: true,
                onPressed: () => _pickImage(context, ImageSource.camera),
              ),
              SizedBox(height: tokens.spaceXl),
              TipCard(title: l10n.homeTipTitle, body: l10n.homeTipBody),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    final XFile? image;
    try {
      // 压缩后再上传：手机原图通常 3~8MB，弱网下容易拖慢识别甚至超时。
      // 1920 宽对 OCR 精度足够，相机与相册两条路径共用此处。
      image = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1920,
        imageQuality: 85,
      );
    } catch (e) {
      // 例如相机或相册权限被拒绝、设备没有摄像头
      debugPrint('pickImage failed: $e');
      if (context.mounted) {
        showInkToast(context, context.l10n.errorGeneric, isError: true);
      }
      return;
    }
    if (image != null && context.mounted) {
      // 新照片：清掉上一轮的结果（否则确认页会显示「重新生成」）
      context.read<AppProvider>().startNewCapture(image);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const OcrPage()),
      );
    }
  }
}

/// 首页插画框：两层微微旋转的底衬（奶油黄圆、浅米色圆角块）+ 卡片底的插画（设计稿 ai_3）。
class _HomeHero extends StatelessWidget {
  const _HomeHero();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final c = context.colors;
    final tilt = tokens.tiltDegrees * math.pi / 180;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: tokens.heroIllustrationMax),
        child: AspectRatio(
          aspectRatio: 1,
          child: Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.all(tokens.spaceSm),
                  child: Transform.rotate(
                    angle: -tilt,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: c.tertiaryFixed.withValues(
                          alpha: tokens.inactiveChipOpacity,
                        ),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.all(tokens.spaceXs),
                  child: Transform.rotate(
                    angle: tilt,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: c.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(tokens.radiusXl),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.all(tokens.spaceLg),
                  child: Container(
                    padding: EdgeInsets.all(tokens.spaceSm),
                    decoration: BoxDecoration(
                      color: tokens.cardSurface,
                      borderRadius: BorderRadius.circular(tokens.radiusXl),
                      boxShadow: tokens.hardShadow(tokens.shadowCard),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(tokens.radiusLg),
                      child: ExcludeSemantics(
                        child: Image.asset(
                          IllustrationKind.home.asset,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Icon(
                            Icons.menu_book,
                            size: tokens.iconTileLg,
                            color: c.primaryContainer,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
