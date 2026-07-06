# 設計ノート・判断記録

## 2026-07-06: 初期計画

### ロードマップ

1. docs基盤 → 2. lib/コア + config + profiles（並列） → 3. modules → 4. install.sh + doctor.sh → 5. 最終レビュー

### 設計方針メモ

- dotfiles-spec.md を設計メモとして参照し、README.md の要件を満たす実装を行う
- README.md は編集禁止（ゴール定義）
- 成果物のみを Git 管理
