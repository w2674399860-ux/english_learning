import 'package:english_learning_app/widgets/app_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

void main() {
  test('Logo 素材已在 pubspec 中声明，可以加载', () async {
    final data = await rootBundle.load(appLogoAsset);
    expect(data.lengthInBytes, greaterThan(0));
  });

  testWidgets('默认边长取 tokens.illustrationSizeSm，图片为图标前景层', (tester) async {
    await pumpLocalized(tester, const Center(child: AppLogo()));

    expect(tester.getSize(find.byType(AppLogo)), const Size.square(160));
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName, appLogoAsset);
  });

  testWidgets('可以指定边长；纯装饰，不进语义树', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpLocalized(tester, const Center(child: AppLogo(size: 96)));

    expect(tester.getSize(find.byType(AppLogo)), const Size.square(96));
    expect(
      find.descendant(
        of: find.byType(AppLogo),
        matching: find.byType(ExcludeSemantics),
      ),
      findsOneWidget,
    );
    semantics.dispose();
  });
}
