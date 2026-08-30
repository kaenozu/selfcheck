# selfcheck

店頭の値札と商品をカメラで確認し、同一商品の過去価格と比較して「いつもより高い・安い」を判断することを目標にしたFlutterアプリです。商品同定はJAN/EANを正本とし、価格は端末内SQLiteへ観測履歴として保存する設計です。

## 現在の状態

このリポジトリは **PoC段階** です。価格比較ドメイン、スキャン状態機械、Driftによる商品・価格履歴、結果UI、単体/結合テストはありますが、現行`master`では実カメラ → JAN/EAN認識 → 価格OCRのproduction pipelineは未接続です。`lib/main.dart`は認識streamにstubを使用しており、実機で主要スキャンフローを完了できません。実カメラ対応はIssue #1のrelease blockerです。

生成済みのFlutter runnerは複数platformに存在しますが、現在の主要受入対象はAndroidです。ストア配布可能性は、実カメラ受入・release signing・CI等の未完了gateを解消してから判断します。

## アーキテクチャ

- `lib/domain/` — `ScanState`、比較結果・比較policyなど副作用を持たないdomain model
- `lib/application/` — `ScanCoordinator`、`CompareUseCase`などuse case / 状態遷移
- `lib/infrastructure/` — barcode/OCR adapter境界、Drift DB、価格repository、stabilizer
- `lib/presentation/` — scan画面、overlay、結果cardなどFlutter UI
- `test/unit/` — domain/application/infrastructureの単体・DBテスト
- `test/integration/` — acceptance contractの統合検証
- `test/widget/` — UI回帰テスト

## データとプライバシー

商品identityと価格観測は端末内SQLite (`selfcheck.sqlite`) に保存します。設計上、カメラframeそのものをDBやファイルへ永続保存する必要はありません。実カメラpipelineを実装する際も、画像を不要に永続化しないことを契約として維持します。

価格履歴はJAN/EANで同定した商品単位で扱います。比較結果を正しくするため、認識途中の不安定な価格や別商品の価格を混在させないことが重要です。

## 必要環境

CI導入PRでは次を基準環境としています。

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

現行PoCでは実カメラ認識pipelineが未実装のため、起動できても実店頭スキャンの完了をrelease acceptanceとして扱わないでください。

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

`AC_VALIDATION_REPORT.md`はPoC acceptanceの過去/現行証跡を読むための補助資料です。READMEの「現在の状態」やGitHubのOpen Issueより古い記述を、現在のrelease readinessとして扱わないでください。

## CI

CI追加はPR #14で管理しています。format/analyze/test、Drift生成物の整合、Android debug buildを自動gateにする方針です。CIが導入されても、実機カメラ受入や正式署名など環境依存gateの代替にはなりません。

## Release

`master`の初期PoCはAndroid release buildでdebug keyを使うため、そのままストア配布してはいけません。release signingのfail-closed化はIssue #12で追跡しています。keystore、password、API keyなどの秘密情報をGitへcommitしないでください。

Production公開、ストアupload、署名credentialの作成/再発行は、コード変更とは分離した明示的なrelease作業として扱います。

## 主要な未完了項目

最新状態はGitHub Issuesを正本として確認してください。特にrelease判断では以下を優先します。

- 実カメラ・JAN/EAN・価格OCR pipeline
- scan lifecycle / stabilizationの回帰修正
- SQLite integrityと履歴整合性
- CI quality gate
- Android release signing

PoCのテストがgreenであることだけを「実機MVP完成」と解釈しないでください。
