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

## 2026-07-06: Round 3 積み残し対応（Round 4）

Round 3 の「教訓・残課題」に挙げた項目一式を解消。

### パッケージマネージャの堅牢化
- `pkg_run_priv` を新設（root 実行時は素通し、非root は sudo 必須・なければ die）。
  apt/dnf/yum の全経路と node.sh/vscode.sh の `sudo` 直書きを置き換え
- apt: `apt` → `apt-get` に統一し、プロセス内で一度だけ `apt-get update` を実行
  （`_APT_UPDATED` フラグ管理）。`DEBIAN_FRONTEND=noninteractive` を付与
- dnf: `--allowerasing` を追加（RHEL9 の curl-minimal 競合を解消）

### curl|sh インストーラの信頼性
- `fetch_and_run_installer`（common.sh）を新設: 一時ファイルにダウンロード→`sh` 実行。
  ダウンロード失敗を確実に検知（従来の `curl | sh` はパイプの失敗を隠蔽していた）
- starship / zoxide（cli-tools.sh）、rustup（rust.sh）、uv（uv.sh）の4箇所を置き換え、
  各インストール後にバイナリ存在チェックで warn する後検証を追加

### cli-tools の部分失敗許容
- eza/fzf/direnv の `pkg_install` 失敗を `warn` して継続する形に変更
  （base.sh は従来通り厳格に abort のまま）

### プロンプトの TTY 必須化
- `_require_tty`（prompt.sh）を新設。YES モード以外で `/dev/tty` が使えない場合は
  die して非対話実行時の素通りを防止。`ask` / `ask_input` / `select_profile` に適用

### chsh 非致命化
- install.sh の chsh 失敗を `warn` に変更し、手動変更手順を案内（インストーラ全体は継続）

### VS Code settings.json の配置
- install.sh の config デプロイループで `vscode/*` をスキップ
- vscode.sh に `_vscode_deploy_settings` を追加し、拡張機能導入後に
  `deploy_file` で OS別パス（macOS: `~/Library/Application Support/Code/User/`、
  Linux: `~/.config/Code/User/`）に配置。README にも配置先を追記
- `_vscode_command` に `/snap/bin/code` フォールバックを追加（snap の bin が
  インストール実行シェルの PATH に無いケースに対応）

### doctor.sh の修正
- repair 成功後に check を再実行し、実際に解消した場合のみ FIXED 表示
  （解消しなければ「repair did not resolve」で fail 扱い）
- `repair_dotfiles_zdotdir` の `cp -rn .../zsh/` を `cp -Rn .../zsh/.` に変更
  （GNU cp でのネスト事故 `.config/zsh/zsh` とドットファイル取りこぼしを解消）
- `check_shell_zsh` の `$USER` 未設定対応（`${USER:-$(id -un)}` をローカル変数化）

### zsh 設定の修正
- 50-aliases.zsh: eza 不在時の ls フォールバックをソース時の一度きりの機能検出に変更
  （`ls --color=auto` 対応可否を probe してからエイリアス定義。従来の
  `||` 実行時フォールバックは per-invocation の挙動不整合があった）
- 10-completion.zsh: kill 補完の `ps` オプションを macOS（BSD ps）/Linux（GNU ps）で分岐
  （`cmd` は GNU 限定、BSD には無い）
- 01-path.zsh / 10-node.zsh: `~/.local/bin` の PATH 追加からディレクトリ存在ガードを撤廃し
  常時追加に変更（`~/bin` のガードは維持）。後からインストールされるツール
  （uv/npm 等）のバイナリを既存シェルでも解決できるように

### git 署名テンプレートの修正（最優先）
- config.template の 1Password セクションに `user.signingkey = __GIT_SIGNING_KEY__` を追加
  （従来 `gpg.format=ssh` + `commit.gpgsign=true` のみで signingkey 未設定のため
  全コミットが失敗していた）
- install.sh: 1Password SSH agent のソケット（`~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock`）
  から `ssh-add -L` で鍵を取得できた場合のみ 1Password セクションを保持し
  `key::<公開鍵>` を signingkey に埋め込む。鍵が取得できない場合は
  1Password 導入済みでもセクションを削除し `warn` で通知（署名なしの通常コミットは可能）
- 既存ユーザーの実 `~/.config/git/config` の修復は本ラウンドのスコープ外
  （テンプレートと生成ロジックの修正のみ。別プロセスで対応予定）

## 2026-07-06: Round 5 安定性修正

### 失敗分離（モジュール/VS Code拡張/zshプラグイン）
- install.sh: モジュール実行を `run_module` 経由に変更し、1モジュールの失敗が
  set -e で全体を巻き込まないように隔離（`FAILED_MODULES` に記録して継続）。
  ただし base packages のみ従来通り致命的（zsh/git は他の前提のため直接呼び出し）
- 完了メッセージを失敗有無で分岐: 失敗があれば
  「dotfiles installation finished with errors」+ 失敗コンポーネント一覧を
  warn 表示して exit 1、無ければ従来通り成功メッセージで exit 0
- vscode.sh: `_vscode_install_extensions` の拡張機能インストール失敗を
  warn に変更し、他の拡張機能のインストールを継続
- zsh-plugins.sh: clone/pull 失敗時は warn して次のプラグインへ継続。
  全プラグインが失敗した場合のみ関数全体を失敗扱い（install.sh 側で
  コンポーネント失敗としてカウントされるように）

### dry-run ログの正確化
- deploy.sh の deploy_file: DRY_RUN 時に「Linked:」「Copied:」と実行済みの
  ように見えるログを出していた問題を修正。DRY_RUN 時は
  「[DRY-RUN] Would link/copy: ...」を表示するよう分岐

### symlink バックアップ
- deploy.sh の backup_file: シンボリックリンクを常にスキップしていたため、
  ユーザーが用意した別ターゲットへのシンボリックリンクが無記録のまま
  削除されていた問題を修正。第2引数 `SKIP_IF_TARGET`（省略可）を追加し、
  リンク先がその値と一致する場合のみバックアップを省略。それ以外の
  シンボリックリンクは `cp -a` でリンクそのものをバックアップする。
  deploy_file の呼び出しを `backup_file "$dest" "$src"` に変更

## 2026-07-07: Rocky Linux 9 実機テストで判明した不具合対応（Round 6）

### run_module の set -e 無効化バグ（最優先）
- install.sh: `if ! "$@"` はコマンドを条件文の位置に置くため、bash の
  仕様でモジュール内部の `set -e` が無効化されてしまい、モジュール途中の
  コマンドが失敗しても後続コマンドが実行され続けていた。Rocky 9 実機で
  確認: install_node 内の `dnf module install nodejs` が失敗（exit 1）した後も
  `_ensure_npm_prefix_config` が実行されて 0 を返すため、install_node 全体が
  「成功」と誤判定され、node 未導入のまま warn も出さず exit 0 していた。
  修正: `run_module` はモジュールをサブシェル `( set -e; "$@" )` の中で
  `set -e` を再有効化して実行し、条件文の位置には置かない形に変更。
  モジュールはサブシェルで動くため、後続ステップへの env export に
  依存できなくなる点を確認済み（CARGO_HOME/RUSTUP_HOME は rust.sh 内で、
  NPM_CONFIG_* は node.sh の check_node/repair_node が都度再導出しており、
  install.sh 側でこれらを参照する箇所も無いため影響なし）

### cmp 欠如による冪等性崩れ
- lib/deploy.sh: Rocky Linux 9 の最小構成コンテナには diffutils（`cmp`）が
  含まれておらず、`cmp -s src dest` が exit 127 になるため、再実行のたびに
  全ファイル（約32個）がバックアップ＋再コピーされていた。
  `_files_identical` ヘルパーを新設し、`cmp` が無い環境では `cksum` による
  内容比較にフォールバックするよう修正。deploy_file の呼び出しを置き換え

### EL9 の nodejs モジュールに既定ストリームが無い問題
- lib/modules/node.sh: Rocky 9 で `dnf module install -y nodejs` が
  「matches 4 streams ... none enabled or default」で失敗することを確認
  （EL8 には既定ストリームがあるが EL9 には無い）。一方 `dnf install nodejs npm`
  は AppStream の v16 で成功する。redhat 分岐を修正し、モジュールインストール
  失敗時は warn の上で `pkg_install nodejs npm` にフォールバックするよう変更

### Red Hat 系での EPEL 自動有効化
- lib/modules/cli-tools.sh: `fzf`（および direnv/eza の一部）が EL9 では
  EPEL リポジトリに含まれるため、install_cli_tools の先頭で
  `pkg_install epel-release` を実行するよう追加。Fedora など epel-release が
  存在しない環境でも warn のみで継続（failure-tolerant）

### npmrc 再デプロイによる churn
- install_node が `~/.config/npm/npmrc` に prefix/cache を書き込んで管理する
  ようになった後も、install.sh の config デプロイループがリポジトリの
  素の npmrc を毎回上書きしてしまい、バックアップの増殖と prefix 設定の
  一時的な消失（次の install_node 実行までの間）を引き起こしていた。
  config デプロイループで `npm/npmrc` は初回デプロイ後（`~/.config/npm/npmrc`
  が既に存在する場合）はスキップするよう修正。以降は node.sh が管理する
- landing pad `~/.zshrc` の再デプロイ上書き（追記消失）を初回のみデプロイに変更。

## 2026-07-07: Round 7 独立レビュー対応

- nvm 検出を XDG パスだけでなく公式デフォルトの `~/.nvm` にも対応。
  `NVM_DIR` 指定、XDG、`~/.nvm` の順に `nvm.sh` が存在するディレクトリを採用し、
  env.d / conf.d / node.sh の判定を揃えた。
- landing pad `~/.zshrc` は単なる存在ではなく `Landing Pad` マーカーで判定。
  既存の外部 `.zshrc` はバックアップして置き換え、既存 landing pad だけ再デプロイを
  スキップする。さらに ZDOTDIR 側 `.zshrc` に再帰 source 防止ガードを追加。
- apt の `_APT_UPDATED` フラグは `apt-get update` 成功時のみ立てるよう修正し、
  失敗時は警告のうえ既存 package list で install を試す。
- Git `merge.conflictstyle=zdiff3` は Git 2.35 未満で壊れるため、生成時に
  バージョン判定して 2.35 以上は `zdiff3`、それ未満は `diff3` を埋め込むよう変更。
- Linux の credential helper は平文 `store` をやめ、`git-credential-libsecret` が
  あれば `libsecret`、なければ 24時間の `cache --timeout=86400` に変更。
- doctor の zsh デプロイチェックを深掘りし、`~/.config/zsh` ディレクトリだけでなく
  `.zshenv` / `.zshrc` の存在も確認するよう変更。
- zsh plugins の doctor チェックをディレクトリ存在だけでなく実際の entry file
  (`zsh-autosuggestions.zsh` / `zsh-syntax-highlighting.zsh`) の readable 判定に変更。
- doctor の `~/.local/bin in PATH` は bash 実行時の PATH だけで誤判定せず、
  zsh が存在する場合は `zsh -lc` の PATH も確認するよう改善。

## 2026-07-07: Round 8 最終レビュー対応

- Git の `core.fsmonitor` / `core.untrackedcache` は Linux の Git で
  `fsmonitor--daemon` 警告を出すため、global `[core]` から外し macOS セクション限定に変更。
- doctor の zsh 検査を完全化。`~/.zshenv` は `~/.config/zsh` を指すこと、
  `~/.zshrc` は landing pad マーカーを持つこと、`env.d` / `conf.d` は
  リポジトリ側の `.zsh` ファイルがすべて配置済みであることを確認するよう変更。
- doctor の `default shell = zsh` に `--fix-sudo` 修復を実装し、
  `sudo chsh -s "$(command -v zsh)" "$USER"` を実行できるようにした。
- macOS の C/C++ doctor チェックで `cmake` だけでなく Xcode Command Line Tools
  (`xcode-select -p`) の存在も確認するよう変更。

## 2026-07-07: Round 9 最終微修正

- Git オプションを生成時にバージョンゲート。`core.fsmonitor` / `core.untrackedcache`
  は Git 2.36 以上、`push.autoSetupRemote` は Git 2.37 以上の場合だけ残すよう
  テンプレートに GIT236/GIT237 マーカーを追加し、古い Git では該当行を削除。
- `sudoers.d PATH` は installer が配布しない任意項目として整理し、
  doctor では存在すれば OK / 無ければ SKIP のみ、`--fix-sudo` 対象外に変更。
- doctor の OS / package manager 検出ログをオプション解析後に移動し、
  `--help` は usage のみ、`--quiet` は検出ログなしで実行されるよう変更。
- `env.d/00-xdg.zsh` の mkdir は read-only HOME 等で zsh 起動時にノイズを出さないよう、
  各 guarded mkdir に `2>/dev/null || true` を付けてエラーを抑止。

## 2026-07-07: Round 10 修正

- doctor の `--fix` で sudo パスワードプロンプトが stderr 抑止に隠れる問題を解消。
  base packages / CLI tools / C/C++ toolchain / VS Code はパッケージ導入系の修復を
  含むため `--fix-sudo` 対象に変更し、plain `--fix` では実行しないようにした。
- git config 生成では `user.name` / `user.email` を quote し、全置換値を 1 行へ
  sanitize。name/email は gitconfig 文字列用に backslash と double quote を
  escape してから sed 置換するようにした。
- sandboxed tool / CI 互換のため、Git テンプレートから `core.fsmonitor` の既定有効化を
  削除。macOS かつ対応 Git では `core.untrackedcache` のみ残す。
- ZDOTDIR 側の `.zshenv` / `.zshrc` は単なる存在ではなく、それぞれ `env.d` /
  `conf.d` を参照していることまで doctor で確認し、修復時は entry file を再デプロイする。
- VS Code は `code` コマンドがある場合、OS 別の `settings.json` が存在することも
  doctor で確認するようにした。
- `grep --color=auto` 非互換という指摘は macOS BSD grep で実測反証できたため不採用。

## 2026-07-07: Round 11 修正

- doctor の修復処理で stderr を抑止しないよう変更し、`--fix-sudo` 実行時の
  sudo パスワードプロンプトや実際のエラーメッセージを表示できるようにした。
  check / re-check は従来どおり stderr を抑止する。
- `--link` から通常の copy 配置へ戻せるよう、deploy_file の symlink 早期 return を
  link mode 限定に変更。copy mode ではリポジトリへの symlink も実ファイルへ置き換える。
- landing pad `~/.zshrc` は marker があっても copy mode かつ symlink の場合は
  skip せず再デプロイし、実ファイルへ戻せるようにした。
- VS Code の doctor 修復は `code` が存在して settings.json が欠ける場合の user-space
  修復のみなので、plain `--fix` 対象へ戻した。

## 2026-07-07: Round 12 修正

- `~/.config/npm/npmrc` は machine-local な prefix/cache を npm が書き込むため、
  `--link` 時も常に copy 配置に変更。さらに `_ensure_npm_prefix_config` の
  `npm config set` 前に既存 symlink を実ファイルへ解参照し、リポジトリ側 npmrc が
  絶対パスで汚れる事故を防ぐようにした。
- landing pad `~/.zshrc` は外部ツールが追記する user-append surface のため、
  `--link` 時も常に copy 配置に変更した。
- doctor の sudo 修復は root 直実行かつ sudo が無い環境でも動くよう、
  `pkg_run_priv` を優先し、fallback でも root の場合は sudo なしで実行するようにした。

## 2026-07-07: Round 13 修正

- shell 関数が `if repair_fn` のような条件文脈で呼ばれると `errexit` が効かないため、
  deploy_file の backup / mkdir / rm / link / copy を明示 rc チェック化。backup 失敗時は
  破壊的手順へ進まず中断するようにした。
- npmrc symlink 解参照も temp 作成・copy・atomic replace の各手順を明示チェックし、
  copy 成功前に元 symlink を削除しない順序へ変更した。
- install.sh の npmrc skip は実ファイルの場合だけに限定し、symlink や broken symlink は
  copy deploy に落として実ファイルへ置き換えるようにした。
- doctor の env.d / conf.d 修復は `cp -rn` をやめ、missing / symlink / unreadable な
  entry を個別に copy redeploy して broken symlink も置き換えられるようにした。

## 2026-07-07: Round 14 修正

- git config 生成時に既存 `~/.config/git/config` が symlink の場合、backup 後に
  symlink 自体を削除してから通常ファイルとして生成するよう変更。machine-local な
  git config が symlink 先を破壊しないようにした。
- doctor の CLI tools 検査でパッケージ入手可否を考慮。`pkg_available` を追加し、
  Ubuntu 22.04 の `eza` のように配布元に存在せず fallback installer もないツールは
  恒久 FAIL にせず、他の repairable な欠落がある場合だけ FAIL にするようにした。

## 2026-07-07: Round 15 修正

- module installer は subshell で実行されるため、Rust / uv などが同一 run 内で追加した
  PATH が後続 module へ伝播しない問題に対応。module 実行前に既知の user-local
  toolchain path を PATH へ前置し、VS Code 拡張判定でも `INSTALL_*` フラグと
  既知パスを考慮するようにした。
- VS Code 拡張インストールは、ある extension group の全拡張が失敗した場合に module
  失敗として返すよう変更。部分失敗は従来どおり警告のみ。
- zsh plugin は一部の clone / pull 失敗でも module 失敗として返し、installer の
  failed component list に記録されるようにした。

## 2026-07-07: Round 16 修正

- Rust doctor は XDG 配下の rustup/cargo だけでなく、PATH 上の rustup/cargo
  （Homebrew 管理など）も installer と同様に OK として扱うようにした。
- CLI tools installer はパッケージ入手不能と導入失敗を分離。入手不能な tool は
  手動導入案内だけで継続し、入手可能なのに `pkg_install` が失敗した場合は module
  失敗として記録するようにした。starship / zoxide の公式 installer 失敗も同様に扱う。
- Vim の `clipboard` option は `+clipboard` 非対応 build でエラーにならないよう
  `has('clipboard')` で guard した。

## 2026-07-07: Round 17 修正

- `pkg_run_priv` は dry-run かつ sudo が無い非 root 環境では abort せず、`sudo ...`
  を DRY-RUN 表示して成功扱いにするようにした。実行時は従来どおり sudo 不在をエラーにする。
- `~/.npmrc` legacy 修復は backup の成功を必須化し、backup に失敗した場合は
  `~/.npmrc` に触らず中断するようにした。
- VS Code doctor は `settings.json` に加えて、常時導入拡張と実在する toolchain に対応する
  拡張の欠落を `code --list-extensions` 1 回で検出するようにした。list 取得に失敗する
  headless 環境では false FAIL を避ける。
- ZDOTDIR の `.zprofile` を doctor の check / repair 対象に追加し、login shell の
  `path_helper` / `brew shellenv` 対応 entry を欠落時に copy 再配置するようにした。
- `common.sh` の DOTFILES_DIR 解決が doctor の repo root 検出を壊すという指摘は実測で
  反証できたため、解決ロジックは変更せず、install.sh 側の説明コメントのみ修正した。

## 2026-07-07: Round 18 修正

- VS Code module は Linux で `snap` が無く本体を導入できない場合に成功扱いで
  skip せず、手動導入手順の案内を出して module 失敗として返すようにした。
- VS Code 拡張導入は一部失敗でも module 失敗として返し、全 extension group を
  試行したうえで installer の failed component list に反映するようにした。
  これにより VS Code のサイレント未導入や拡張の部分欠落を見落とさない。

## 2026-07-07: Round 19 修正

- CLI tools の入手可否判定は `pkg_install` を試した後に行う順序へ変更した。
  `apt-get update` 前の空メタデータで `eza` などを誤って入手不能扱いにする問題を防ぐ。
- starship / zoxide / rustup / uv の公式 installer は、dry-run 以外で導入後の
  binary post-check に失敗した場合、警告だけでなく module 失敗として返すようにした。
