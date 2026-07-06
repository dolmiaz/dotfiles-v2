# 設計ノート・判断記録

## 2026-07-06: 初期計画

### ロードマップ

1. docs基盤 → 2. lib/コア + config + profiles（並列） → 3. modules → 4. install.sh + doctor.sh → 5. 最終レビュー

### 設計方針メモ

- dotfiles-spec.md を設計メモとして参照し、README.md の要件を満たす実装を行う
- README.md は編集禁止（ゴール定義）
- 成果物のみを Git 管理

## 2026-07-06: Codex xhigh レビュー結果

### 修正済み（HIGH）
- prompt.sh: stdout/stderr 分離（メニューやプロンプトが値に混入していた）
- install.sh: git config の再生成時バックアップ + デフォルト値の取得
- doctor.sh: モジュールcheck関数が未インストールをFAIL判定していた
- doctor.sh: repair関数がバックアップなしで上書きしていた
- rust.sh: CARGO_HOME/RUSTUP_HOME のXDGパス不整合
- readlink -f: macOS互換性修正（common.sh, install.sh, doctor.sh）

### 修正済み（MEDIUM）
- deploy.sh: LINK_MODE デフォルトをcopyに変更（ヘルプと整合）
- node.sh: Red Hat系でyumフォールバック追加
- vscode.sh: snap存在チェック追加
- config.template: delta/lfs/1Password の条件分岐追加
- node.sh: npm config のXDGパス対応

### 対応不要（LOW）
- env.d/00-xdg.zsh の mkdir -p: 冪等で実害なし、変更不要と判断

### README提案
README.md の Status セクションに「initial setup phase」とあるが、実装は完了済み。
README編集禁止のため、push前にユーザーに確認する。
