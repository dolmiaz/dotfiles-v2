# 実装進捗

## チェックリスト（README.md 完了条件）

### コマンド
- [ ] `install.sh --profile desktop` が動作する
- [ ] `install.sh --profile server` が動作する
- [ ] `install.sh --profile minimal` が動作する
- [ ] `install.sh --dry-run` が動作する
- [ ] `doctor.sh` が動作する
- [ ] `doctor.sh --fix` が動作する

### 設計目標
- [ ] XDG-style 設定パス（$HOME を散らかさない）
- [ ] env.d / conf.d によるモジュラーシェル設定
- [ ] macOS / Debian系 / Red Hat系 対応
- [ ] 冪等なセットアップスクリプト + dry-run
- [ ] AI/editor/cache/machine-specific ファイルが GitHub に出ない

### リポジトリ方針
- [ ] 成果物のみが Git 管理されている
- [ ] README.md は変更されていない
- [ ] 許可外の .md ファイルが増えていない

## フェーズ進捗

| フェーズ | 内容 | 状態 |
|---------|------|------|
| 1 | docs 基盤作成 | 作業中 |
| 2 | lib/ コア + config/ + profiles/ | 未着手 |
| 3 | lib/modules/*.sh | 未着手 |
| 4 | install.sh + doctor.sh | 未着手 |
| 5 | 最終レビュー | 未着手 |
