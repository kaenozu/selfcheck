# selfcheck

店頭の値札と商品をカメラで確認し、同一商品の過去価格と比較して「いつもより高い・安い」を判断することを目標にしたFlutterアプリです。商品同定はJAN/EANを正本とし、価格は端末内SQLiteへ観測履歴として保存する設計です。

## 現在の状態

このリポジトリは **PoC / MVP受入途中** です。価格比較ドメイン、スキャン状態機械、Driftによる商品・価格履歴、結果UI、単体/結合テストがあります。

実カメラ → JAN/EAN認識 → 価格OCRのproduction pipelineは Issue #1 / Draft PR #35 で実装・検証中です。コードが存在することと実機Acceptance完了は分けて扱い、Issue #1 の実機条件（permission、live preview、EAN認識、価格OCR、lifecycle、airplane mode、storage/cache確認）が完了するまでは主要スキャンフローをリリース済みとは扱いません。

生成済みのFlutter runnerは複数platformに存在しますが、現在の主要受入対象はAndroidです。iOSはPR #35のplugin/configurationに対してno-codesign build gateをIssue #36 / Draft PR #46で追加中です。ストア配布可能性は、実機受入・release signing・CI等のgateを解消してから判断します。

## アーキテクチャ

- `lib/domain/` — `ScanState`、比較結果・比較policyなど副作用を持たないdomain model
- `lib/application/` — `ScanCoordinator`、`CompareUseCase`などuse case / 状態遷移
- `lib/infrastructure/` — barcode/OCR adapter境界、Drift DB、価格repository、stabilizer
- `lib/presentation/` — scan画面、overlay、結果cardなどFlutter UI
- `test/unit/` — domain/application/infrastructureの単体・DBテスト
- `test/integration/` — acceptance contractの統合検証
- `test/widget/` — UI回帰テスト

## データとプライバシー

商品identityと価格観測は端末内SQLite (`selfcheck.sqlite`) に保存します。カメラframeそのものをDBやファイルへ永続保存しないことを設計契約とし、実カメラpipelineでもフレームは端末内認識の入力としてメモリ上で扱います。

価格履歴はJAN/EANで同定した商品単位で扱います。比較結果を正しくするため、認識途中の不安定な価格や別商品の価格を混在させないことが重要です。

## 必要環境

CIの基準環境は次のとおりです。

- Flutter 3.44.0
- Dart 3.12系
- Java 17
- Android SDK（debug APKをbuildできる構成）

ローカル環境のFlutter/Dartが要件を満たしていることを確認してください。

```bash
flutter --version
java -version
```

## セットアップ

```bash
flutter pub get
```

生成済みDriftコードを更新する必要がある変更では次を実行します。

```bash
dart run build_runner build --delete-conflicting-outputs
```

生成後は意図しない差分がないことを確認してください。

## 実行

接続済みAndroid端末またはemulatorを確認してから起動します。

```bash
flutter devices
flutter run
```

実カメラpipelineのコードが入ったbranchでも、実機Acceptanceが未完了なら店頭スキャンをrelease acceptanceとして扱わないでください。現在の正確な状態はIssue #1と関連Draft PRを確認してください。

## 品質ゲート

変更後は少なくとも以下を実行します。

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test --reporter expanded
dart run build_runner build --delete-conflicting-outputs
git diff --exit-code -- lib/infrastructure/database/app_database.g.dart
flutter build apk --debug
git diff --check
```

`AC_VALIDATION_REPORT.md`はPoC acceptanceの証跡です。enumの存在やin-memory処理だけを実機Acceptanceの代用にせず、physical-device依存条件はPENDINGとして扱います。最新状態はGitHub Issuesとexact-head CIを正本にしてください。

## CI

`master` の `.github/workflows/ci.yml` では、Flutter 3.44.0 / Java 17を使って次を自動検証します。

- `flutter analyze`
- full `flutter test`
- Drift生成コード整合性
- Android debug APK build
- 変更Dartファイルのformatter準拠

iOSのcamera/ML Kit統合については、Issue #36 / Draft PR #46で `flutter build ios --debug --no-codesign` の恒久gateを追加中です。CIがgreenでも、実機カメラ受入や正式署名など環境依存gateの代替にはなりません。

## Release

Android release signingはIssue #12でfail-closed化を追跡しています。keystore、password、API keyなどの秘密情報をGitへcommitしないでください。

Production公開、ストアupload、署名credentialの作成/再発行は、コード変更とは分離した明示的なrelease作業として扱います。

## 主要な未完了項目

最新状態はGitHub Issuesを正本として確認してください。特にrelease判断では以下を優先します。

- Issue #1: 実カメラ・JAN/EAN・価格OCRの実機Acceptance
- Issue #10: acceptance evidenceのfail-closed化とdevice-only gate
- Issue #12: Android release signing
- Issue #36: iOS no-codesign CI gate
- DB整合性・重複判定・scan lifecycleの各修正PR

自動テストがgreenであることだけを「実機MVP完成」と解釈しないでください。
