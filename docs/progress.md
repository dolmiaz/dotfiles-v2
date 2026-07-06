# 実装進捗

## チェックリスト（README.md 完了条件）

### コマンド
- [x] `install.sh --profile desktop` が動作する
- [x] `install.sh --profile server` が動作する
- [x] `install.sh --profile minimal` が動作する
- [x] `install.sh --dry-run` が動作する
- [x] `doctor.sh` が動作する
- [x] `doctor.sh --fix` が動作する

### 設計目標
- [x] XDG-style 設定パス（$HOME を散らかさない）
- [x] env.d / conf.d によるモジュラーシェル設定
- [x] macOS / Debian系 / Red Hat系 対応
- [x] 冪等なセットアップスクリプト + dry-run
- [x] AI/editor/cache/machine-specific ファイルが GitHub に出ない

### リポジトリ方針
- [x] 成果物のみが Git 管理されている
- [x] README.md は変更されていない
- [x] 許可外の .md ファイルが増えていない

## フェーズ進捗

| フェーズ | 内容 | 状態 |
|---------|------|------|
| 1 | docs 基盤作成 | 完了 |
| 2 | lib/ コア + config/ + profiles/ | 完了 |
| 3 | lib/modules/*.sh | 完了 |
| 4 | install.sh + doctor.sh | 完了 |
| 5 | Codex xhigh レビュー + 修正 | 完了 |
| 6 | 最終確認 | 完了 |

## 追加ラウンド（2026-07-06: UX改善 + README刷新）

- [x] Round 1 設計レビュー（監督者 + Codex xhigh）
- [x] bash 3.2 互換性修正（macOS 標準 bash で動作）
- [x] copy モード冪等化（内容一致ならスキップ）
- [x] インストールサマリ + 最終確認フロー（拒否時は無変更で中止）
- [x] コンポーネント名の太字表示
- [x] doctor.sh 3状態化（OK / FAIL / SKIP）
- [x] README を日本語で全面刷新（外部ユーザー向け）
- [x] Round 2 最終レビュー（Codex xhigh: SHIP 判定）
