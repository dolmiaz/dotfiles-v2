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
| 6 | 最終確認 | 作業中 |
