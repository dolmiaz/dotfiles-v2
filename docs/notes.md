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
→ 2026-07-06: ユーザー指示により README 全面書き直し（日本語・外部向け）が決定。編集禁止は解除。
→ 2026-07-06: 書き直し後、ユーザーに明示確認を実施し「書き直し版を維持・編集禁止制約は正式解除」との回答を得た。
  旧英語版（ゴール定義）は git 履歴（27df0f4 以前）に保存されている。旧ゴールの完了条件
  「README.md は変更されていない」は旧ゴール達成判定時点（27df0f4）で満たされており、
  以後の README は外部向けドキュメントとして扱う。

## 2026-07-06: Round 1 設計レビュー（監督者 + Codex xhigh）

「dotfiles の導入として適切な作りか」の観点でダブルレビューを実施。

### 修正対象（HIGH）
- **bash 3.2 互換性**: prompt.sh の `${var^^}` / `${answer^^}` は bash 4 構文。
  macOS 標準 `/bin/bash`（3.2）で `bad substitution` になり install 不能（Codex が実証）。→ Agent A
- **copy モードの冪等性欠如**: deploy_file が再実行のたびに同一内容でも
  バックアップ→再コピーする。バックアップ増殖 + ~/.zshrc landing pad への
  ユーザー追記を毎回退避・上書き。→ 内容一致（cmp -s）ならスキップに変更。→ Agent A
- **doctor.sh の診断モデル**: 未インストール＝OK 表示で healthy と区別できない。
  sudoers.d チェックは installer が作成しないファイルを常に FAIL 判定し exit 1。
  → check_* を3状態（0=OK / 1=FAIL / 2=SKIP）化、doctor.sh で SKIP 表示。→ Agent C

### 修正対象（MEDIUM/LOW）
- Homebrew 不在の macOS で警告のみ出して途中で死ぬ → install.sh 冒頭で早期 die + 導入手順表示。→ Agent A
- env.d/00-xdg.zsh が既存の XDG_* を強制上書き → `${XDG_CONFIG_HOME:-...}` で尊重。→ Agent C
- node.sh の `mkdir -p` が run() を経由せず dry-run 契約違反。→ Agent C

### 記録のみ（今回スコープ外・将来課題）
- アンインストール/ロールバック: マニフェスト方式（デプロイ先の記録）+ uninstall.sh の設計が必要
- install.sh と doctor.sh でコンポーネントレジストリが二重管理（ドリフトの温床）
- パッケージ移植性: Debian の eza 収録有無、VS Code の snap 前提、dnf module のストリーム未指定
  → README に「環境により手動インストールが必要」と明記して緩和
- deploy_file が既存 symlink（別ターゲット）をバックアップなしで削除する

### 総評（Codex）
アーキテクチャの骨格（XDG、ZDOTDIR landing pad、モジュラー zsh、install_/check_/repair_ 三点セット）は
適切。bash 3.2 問題と状態管理（冪等 copy、doctor 整合、ロールバック）を解消すれば堅実なインストーラになる。

## 2026-07-06: UX改善 + README刷新 + Round 1 指摘修正（3エージェント並列）

### 実装内容
- **install.sh UX**: 全質問（コンポーネント太字表示・git識別情報・chsh）を先に解決 →
  インストールサマリ一覧表示 → `Proceed with installation? [Y/n]` の最終確認 → 確認通過後にのみ実行。
  拒否時は無変更で exit 0。--yes は最終確認も自動承認
- **bash 3.2 互換**: prompt.sh の `${var^^}` を tr に置換。macOS 標準 /bin/bash で全プロファイル動作確認
- **copy 冪等化**: deploy_file が内容一致（cmp -s）ならスキップ（`Up to date` 表示）
- **早期エラー**: パッケージマネージャ不在時は導入手順を表示して即終了
- **doctor.sh 3状態化**: check_* が 0=OK / 1=FAIL / 2=SKIP。未インストールは SKIP 表示、
  SKIP は修復対象外かつ exit 1 に寄与しない。sudoers.d は SKIP (optional) に変更
- **README**: 日本語で全面刷新（外部ユーザー向け: プロファイル比較表、コンポーネント詳細、
  オプション、対話フロー、導入後の構成、冪等性、既知の制限）

### Round 2 レビュー結果（監督者 + Codex xhigh）
- Codex xhigh: **SHIP 判定**。HIGH/MEDIUM なし、LOW 2件（README の --fix 表現、
  git config 生成物の冪等性例外の注記漏れ）→ 統合時に文言修正済み
- 監督者検証: bash -n / zsh -n 全パス、/bin/bash 3.2 で --dry-run --yes ×3プロファイル exit 0、
  サマリブロック表示確認、doctor.sh の SKIP 表示と exit code 動作確認
- 既知の軽微事項（記録のみ）: dry-run 時に deploy_file が [DRY-RUN] 行に続けて
  「Copied:」ログを出す（実コピーはしていない。従来からの表示上の紛らわしさ）

## 2026-07-06: npm EACCES 障害対応と関連堅牢化（Round 3）

### 障害内容
- `npm install -g` が EACCES で失敗。原因の複合: root 所有の `~/.npm`、壊れた cache、
  npmrc の `prefix=~/.local` が nvm と衝突、lazy-load 前後に npm が root 所有の
  `/usr/local/bin/npm`（旧 Node.js pkg の残骸）へ落ちる

### 応急修正（別セッション）+ 本ラウンドのレビュー修正
- npmrc: `cache=~/.cache/npm` のみの最小形に（prefix 行を削除）
- node.sh: `_ensure_npm_prefix_config` 導入 — 非 nvm 環境は npmrc に prefix を書き戻し
  （bash/cron からも有効）、nvm 環境は prefix 行を削除。cache も永続化（アップグレード経路対応）。
  `check_node` は env 非依存で永続設定を検査（自己充足チェックの排除）
- doctor: `npm prefix/cache` に改名 + `npm dir ownership`（root 所有検知、--fix-sudo で chown）
  + `~/.npmrc legacy`（prefix/globalconfig 競合検知・修復）を追加
- env.d/10-node.zsh: nvm 存在時に default バージョンの bin を静的 PATH 追加
  （非対話 zsh でも nvm の npm に解決。~/.local/bin より前に配置）
- .zprofile: 独自 path_helper 呼び出しを削除し、末尾で env.d を再 source
  → /etc/zprofile の path_helper による PATH 降格を解消（Round 1 指摘の恒久対応。
  実機で git が brew 版に解決するようになった）
- 20-nvm.zsh: `--no-use` + default alias ガード + NVM_BIN の PATH 復帰 + 非TTY補完抑止
- rust.sh: CARGO_HOME/RUSTUP_HOME の既存 env 尊重、XDG 移行はデフォルトパスのみ
- vscode.sh: macOS app bundle CLI フォールバック / starship.toml 刷新（警告なし確認済み）

### 検証
- macOS 実機: `zsh -lc` / `TERM=dumb zsh -lic` とも npm が nvm 版（v23.11.0）に解決、
  `npm install -g @openai/codex --dry-run` exit 0、doctor 17 passed 2 skipped
- Ubuntu 24.04 コンテナ: 非 nvm（prefix 書き戻し・素の bash で有効）/ nvm（prefix 自動除去・
  非対話 zsh で nvm 解決）/ legacy npmrc 修復 / 所有権検知・修復 の 7 シナリオ合格
- Codex xhigh: 初回 SHIP 不可（HIGH: cache 永続化漏れ、MEDIUM: ~/.local/bin が nvm を
  シャドウ、LOW: grep の空白許容）→ 3件修正後に **SHIP 判定**

### 教訓・残課題
- sandbox 環境で npm を実行すると EPERM が「root-owned files」と誤診される（検証時の注意）
- Round 1 指摘の未対応分は別タスク: RHEL9 curl 競合、curl|sh 失敗マスク、TTY なし確認素通り、
  apt update 未実行、ls エイリアス、VS Code settings.json 配置先、doctor の repair errexit
