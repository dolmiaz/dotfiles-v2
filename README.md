# dotfiles

macOS / Linux を横断して開発環境を再現するためのクロスプラットフォーム dotfiles です。XDG Base Directory 仕様に沿って `$HOME` を汚さない構成を採り、対話式のインストーラ（`install.sh`）でプロファイル選択からコンポーネント単位の取捨選択、git のユーザー設定までを一括でセットアップします。導入後は `doctor.sh` で環境の健全性を診断・修復できます。

## 対応環境

| OS | パッケージマネージャ |
|---|---|
| macOS | Homebrew (`brew`) |
| Debian 系 Linux（Debian / Ubuntu / Mint / Pop!_OS / Raspbian など） | `apt` |
| Red Hat 系 Linux（Fedora / RHEL / CentOS / Rocky / Alma など） | `dnf`（なければ `yum`） |

前提条件:

- `git`（このリポジトリの clone に必要）
- macOS の場合は **Homebrew を先に導入**してください（<https://brew.sh>）。パッケージマネージャが見つからない場合、`install.sh` は導入手順を案内して早期に終了し、システムには一切変更を加えません。

## クイックスタート

```sh
git clone https://github.com/dolmiaz/dotfiles-v2.git
cd dotfiles-v2

# まずは dry-run で何が行われるかを確認（推奨）
./install.sh --dry-run

# 問題なければ本実行
./install.sh
```

## プロファイル

インストーラは 3 つのプロファイルを提供します。プロファイルは「各コンポーネントを入れるかどうかの初期値」を決めるだけで、最終的な Yes/No は対話プロンプトで個別に選べます。

- **desktop** — GUI マシン向け。開発ツールチェーンと VS Code を含むフルセット
- **server** — ヘッドレス環境向け。CLI 中心で、GUI 関連はスキップ
- **minimal** — 最小構成。基本パッケージと git 設定、シェル変更のみ

| コンポーネント | desktop | server | minimal |
|---|:---:|:---:|:---:|
| base（基本パッケージ） | Y | Y | Y |
| cli-tools（モダン CLI） | Y | Y | SKIP |
| c-cpp（C/C++ ツールチェーン） | Y | N | SKIP |
| rust | Y | N | SKIP |
| uv（Python） | Y | N | SKIP |
| node（Node.js） | N | N | SKIP |
| vscode（VS Code + 拡張） | Y | SKIP | SKIP |
| zsh-plugins | Y | Y | SKIP |
| git config | Y | Y | Y |
| chsh（デフォルトシェルを zsh に） | Y | Y | Y |

凡例:

- **Y** — 確認プロンプトあり。デフォルトは Yes（Enter で導入）
- **N** — 確認プロンプトあり。デフォルトは No（明示的に y と答えたときだけ導入）
- **SKIP** — 質問すら表示されず、常にスキップ

## 各コンポーネントの中身

### base

必須パッケージ: `zsh` `git` `vim` `curl` `wget` `unzip`

### cli-tools

モダン CLI ツール: `eza` `fzf` `zoxide` `starship` `direnv`

`eza` / `fzf` / `direnv` はパッケージマネージャから、`starship` と `zoxide` は未導入の場合に公式インストーラ（curl | sh）で導入します。

### c-cpp

- macOS: Xcode Command Line Tools（未導入なら `xcode-select --install`）+ `cmake`
- Debian 系: `build-essential` `cmake` `gdb`
- Red Hat 系: `gcc` `gcc-c++` `cmake` `gdb`

### rust

rustup 公式インストーラで導入します（`--no-modify-path`）。`CARGO_HOME` / `RUSTUP_HOME` は XDG 準拠の `~/.local/share/cargo` / `~/.local/share/rustup` に配置され、PATH 設定は `env.d/10-rust.zsh` が担当します。導入済みの場合は `rustup update` を実行します。

### uv

Python パッケージマネージャ uv を公式インストーラで導入します。キャッシュ・ツールデータは XDG ディレクトリ配下（`~/.cache/uv`、`~/.local/share/uv/tools`）です。

### node

- macOS: `brew install node`
- Debian 系: `nodejs` `npm`
- Red Hat 系: `dnf module install nodejs`（既定ストリーム）

導入後、npm の cache は XDG 準拠の `~/.cache/npm` を使います。グローバル prefix は nvm が無い環境でのみ `~/.local` に設定し（root 不要のグローバルインストール）、nvm がある環境では prefix を設定せず nvm 管理に任せます。npmrc は `~/.config/npm/npmrc` です。

### vscode

VS Code 本体（macOS は Homebrew Cask、Linux は snap）と拡張機能を導入します。

- 常に導入: Remote SSH / Remote Explorer / EditorConfig / Prettier
- 条件付き導入（該当ツールチェーンが存在する場合のみ）: C/C++（cpptools, cmake-tools）、Rust（rust-analyzer）、Python（python, pylance）、Node.js（eslint）

### zsh-plugins

`zsh-autosuggestions` と `zsh-syntax-highlighting` を `~/.local/share/zsh/plugins/` に git clone します（導入済みなら `git pull` で更新）。

### git config

`config/git/config.template` から `~/.config/git/config` を生成します。

- 対話プロンプトで `user.name` / `user.email` を入力（既存の git 設定値がデフォルト）
- credential helper は OS に応じて自動選択（macOS: `osxkeychain`、Linux: `store`）
- git-lfs が導入済みなら LFS セクション、1Password（macOS）が存在すれば SSH 署名セクションを有効化
- グローバル ignore（`~/.config/git/ignore`）も配置

### chsh

デフォルトシェルが zsh でない場合、確認のうえ `chsh -s $(command -v zsh)` を実行します。`--no-chsh` で無効化できます。

## install.sh

### オプション

| オプション | 説明 |
|---|---|
| `--profile PROFILE` | プロファイルを指定（`desktop` / `server` / `minimal`）。省略時は対話選択 |
| `--yes` | すべてのプロンプトをデフォルト値で自動承認（CI 向け）。最終確認も自動承認 |
| `--link` | ファイルをコピーではなくシンボリックリンクで配置 |
| `--dry-run` | 実際には変更せず、実行内容だけを表示 |
| `--no-chsh` | デフォルトシェルの変更を行わない |
| `-h`, `--help` | ヘルプを表示 |

### 対話フロー

1. **プロファイル選択** — `--profile` 未指定なら対話で選択
2. **コンポーネントごとの Y/N 確認** — コンポーネント名は太字で表示。プロファイル値が SKIP のものは質問自体が出ません
3. **git ユーザー情報の入力** — `user.name` / `user.email`
4. **シェル変更の確認** — デフォルトシェルを zsh にするか
5. **インストールサマリの表示** — プロファイル、OS、配置モード（copy / link）、各コンポーネントの導入/スキップ、git ユーザー情報、chsh の有無を一覧表示
6. **最終確認** — `Proceed with installation? [Y/n]`。ここで No と答えると**システムに一切変更を加えず**に中止します

ここまでの質問はすべて「答えを集めるだけ」で、実際の変更は最終確認を通過した後に始まります。

## doctor.sh

`brew doctor` / `flutter doctor` 風の診断・修復ツールです。

```sh
./doctor.sh          # 診断のみ
./doctor.sh --fix    # sudo 不要な問題の修復を試みる
```

主なチェック項目:

- `~/.zshenv` の存在と ZDOTDIR 設定
- `~/.zshrc`（landing pad）の存在
- `~/.config/zsh` と `env.d/` / `conf.d/` のファイル配置
- `~/.local/bin` が PATH に含まれるか
- 各コンポーネント（base パッケージ、CLI ツール、C/C++、Rust、uv、npm prefix/cache、npm ディレクトリ所有権、レガシー `~/.npmrc`、VS Code、zsh プラグイン）の健全性
- git の user.name / user.email 設定
- デフォルトシェルが zsh か、`/etc/sudoers.d/dotfiles-path` の有無（修復には sudo が必要）

結果は 3 状態で報告されます:

| 状態 | 意味 |
|---|---|
| **OK** | 正常 |
| **FAIL** | 問題あり（`--fix` / `--fix-sudo` で修復できるものもあります） |
| **SKIP** | そのマシンに導入していない、または対象外のコンポーネント。**エラーではありません** |

オプション:

| オプション | 説明 |
|---|---|
| `--fix` | sudo 不要な問題の自動修復を試みる（自動修復手段のない項目は FAIL のまま報告） |
| `--fix-sudo` | sudo が必要な項目も修復対象に含める |
| `--quiet` | 問題のある項目だけを表示 |
| `-h`, `--help` | ヘルプを表示 |

## 導入後の構成

zsh の設定は次の順序で読み込まれます。

```
~/.zshenv                       # ZDOTDIR=~/.config/zsh を設定するだけの薄いブートストラップ
  └─ ~/.config/zsh/.zshenv      # env.d/*.zsh を番号順に source（全セッション共通）
       └─ env.d/                # 環境変数・PATH のみ。対話用コードは置かない
~/.config/zsh/.zshrc            # 対話シェルのみ。conf.d/*.zsh を番号順に source
  ├─ conf.d/                    # エイリアス、補完、fzf/zoxide/direnv/starship 連携など
  └─ ~/.zshrc                   # 最後に landing pad を source
```

- **landing pad 方式**: `~/.zshrc` は本体設定の**末尾から** source される追記用ファイルです。外部ツール（各種インストーラなど）が `~/.zshrc` に追記しても壊れず、そのまま反映されます。自分の設定を足す場合は `~/.config/zsh/conf.d/` に新しい `.zsh` ファイルを作るのが推奨です。
- **XDG 方針**: `XDG_CONFIG_HOME` / `XDG_DATA_HOME` / `XDG_CACHE_HOME` / `XDG_STATE_HOME` を設定し、zsh 履歴・補完キャッシュ・cargo/rustup・Go・npm・uv のデータをすべて `~/.config` `~/.local/share` `~/.cache` `~/.local/state` 配下に集約して `$HOME` 直下を汚しません。

## リポジトリ構成

```
dotfiles-v2/
├── install.sh          # インストーラ本体
├── doctor.sh           # 診断・修復ツール
├── lib/
│   ├── common.sh       # ログ・実行ラッパー（DRY_RUN 対応）
│   ├── detect.sh       # OS / パッケージマネージャ検出
│   ├── prompt.sh       # 対話プロンプト（--yes 対応）
│   ├── deploy.sh       # ファイル配置（copy / link / バックアップ）
│   └── modules/        # コンポーネント別インストーラ（base, cli-tools, c-cpp, rust, uv, node, vscode, zsh-plugins）
├── profiles/           # desktop.conf / server.conf / minimal.conf
├── config/             # ~/.config/ に配置されるファイル（zsh, git, vim, vscode, npm, prettier, starship）
├── home/               # ~/ 直下に配置されるファイル（.zshenv, .zshrc, .vimrc）
└── docs/               # 開発メモ
```

## 冪等性とバックアップ

- `install.sh` は**再実行しても安全**です。内容が変わっていないファイルはスキップされ、変更のあるファイルだけが更新されます（テンプレートから生成される `~/.config/git/config` のみ、再生成のたびにバックアップ→上書きされます）。
- 既存ファイルを置き換える前に、同じ場所へ `<ファイル名>.bak.<タイムスタンプ>` としてバックアップを作成します。
- 配置モードは 2 種類:
  - **copy（デフォルト）** — リポジトリからファイルをコピー。リポジトリを消しても環境はそのまま動きます
  - **`--link`** — シンボリックリンクで配置。リポジトリの編集が即座に反映されますが、リポジトリの場所を動かせなくなります
- **アンインストールコマンドは提供していません。** 元に戻す場合は、各所に残る `.bak.<タイムスタンプ>` ファイルから手動で復元してください。

## 既知の制限

- 一部パッケージはディストリビューションによって手動導入が必要になる場合があります（例: 古い Debian/Ubuntu では `eza` がリポジトリにない）。
- Linux での VS Code 導入は snap 前提です。snap がない環境では VS Code 本体の導入はスキップされます。
- Red Hat 系の Node.js は `dnf module` の既定ストリームを使うため、特定バージョンが必要な場合は事前にストリームを切り替えてください。
- `doctor.sh --fix` で直せない項目（PATH 設定、git ユーザー設定など）は手動対応が必要です。

## リポジトリポリシー

このリポジトリには再利用可能な dotfiles 資産のみを commit します。以下は意図的に管理対象外です。

- AI エージェント設定・ローカル計画メモ
- 生成されたキャッシュ・ログ
- 秘密情報（トークン、鍵、認証情報）
- マシン固有の設定
