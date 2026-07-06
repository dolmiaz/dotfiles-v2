# dotfiles

Personal dotfiles for setting up a development environment across macOS and
Linux.

## Status

This repository is in its initial setup phase. The public repository currently
contains only the README and repository hygiene rules. The actual dotfiles
installer and configuration files will be added as implementation progresses.

## Planned Usage

The v2 workflow is intended to provide an interactive installer with profiles:

```sh
./install.sh --profile desktop
./install.sh --profile server
./install.sh --profile minimal
```

Before applying changes to a machine, the installer should support a dry run:

```sh
./install.sh --dry-run
```

After installation, the repository should provide a doctor command for
diagnostics and repair:

```sh
./doctor.sh
./doctor.sh --fix
```

## Design Goals

- Keep `$HOME` clean by using XDG-style configuration paths.
- Keep shell configuration modular with `env.d` and `conf.d`.
- Support macOS, Debian-based Linux, and Red Hat-based Linux.
- Prefer idempotent setup scripts with clear dry-run behavior.
- Keep local-only AI, editor, cache, and machine-specific files out of GitHub.

## Repository Policy

Only reusable dotfiles artifacts should be committed. Local planning notes,
AI-agent configuration, generated caches, logs, secrets, and machine-specific
settings are intentionally ignored.
