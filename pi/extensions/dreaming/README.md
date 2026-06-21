# dreaming extension for pi

Long-term memory extension for pi. Extracts durable facts from conversations into an Obsidian-like knowledge vault and keeps a small sidecar state.

## What it does

MVP behavior:

- Runs extraction after `agent_end`.
- Uses the current pi model (`ctx.model`).
- Writes accepted cards to `<vault>/dreaming/{personal,knowledge}/`.
- Keeps operational state in `~/.pi/dreaming/` by default.
- Provides `/dream` commands for status, path config, git-sync config and manifest refresh.

Not implemented yet: full dream consolidation, review queue, immutable revisions, structured validation issues, TemporalValue, sharing export, auto-dream.

## Files

Install directory:

```text
~/.pi/agent/extensions/dreaming/
├── README.md
├── config.ts
├── index.ts
├── dream/
│   └── command.ts
├── extraction/
│   ├── pipeline.ts
│   ├── prompt.ts
│   └── transcript.ts
└── kb/
    ├── card.ts
    ├── git.ts
    ├── io.ts
    └── state.ts
```

Pi auto-discovers this layout because it is `~/.pi/agent/extensions/<name>/index.ts`.

## Install from dotfiles

Copy/symlink the directory into pi extensions:

```bash
mkdir -p ~/.pi/agent/extensions
ln -s ~/dotfiles/pi/extensions/dreaming ~/.pi/agent/extensions/dreaming
# or copy:
# cp -R ~/dotfiles/pi/extensions/dreaming ~/.pi/agent/extensions/dreaming
```

Then reload pi:

```text
/reload
```

or restart pi.

## Settings

Config file:

```text
~/.pi/dreaming/settings.json
```

Minimal personal machine config:

```json
{
  "schemaVersion": 1,
  "vault": "~/Documents/Zettel/Knowledge"
}
```

With git sync enabled:

```json
{
  "schemaVersion": 1,
  "vault": "~/Documents/Zettel/Knowledge",
  "gitSync": true
}
```

With custom sidecar location:

```json
{
  "schemaVersion": 1,
  "vault": "~/Documents/Zettel/Knowledge",
  "sidecar": "~/.pi/dreaming",
  "gitSync": true
}
```

On a work computer, use the work vault path in the same file:

```json
{
  "schemaVersion": 1,
  "vault": "~/PATH/TO/WORK/KNOWLEDGE",
  "gitSync": true
}
```

`~` is expanded.

## Environment overrides

Useful for tests/CI/temporary runs:

```bash
export DREAMING_VAULT_ROOT=/absolute/path/to/vault
export DREAMING_SIDECAR_ROOT=/absolute/path/to/sidecar
export DREAMING_GIT_SYNC=true
```

Env has priority over `settings.json`.

## Commands

```text
/dream
```

Shows status: vault path, sidecar path, gitSync, card counts, last extraction/dream.

```text
/dream path
/dream path ~/Documents/Zettel/Knowledge
```

Show or set vault path. Writes `~/.pi/dreaming/settings.json`.

```text
/dream git-sync
/dream git-sync true
/dream git-sync false
```

Show or set git sync.

```text
/dream manifest
```

Rebuilds `<vault>/dreaming/{personal,knowledge}/_index.md` and `<vault>/dreaming/_manifest.json`.

```text
/dream accept <id>
```

Reserved for phase 2 review queue.

## Vault layout

Dreaming writes only under `<vault>/dreaming/`:

```text
<vault>/
└── dreaming/
    ├── _manifest.json
    ├── personal/
    │   ├── _index.md
    │   └── {slug}__{id}.md
    └── knowledge/
        ├── _index.md
        ├── people/
        ├── repos/
        ├── infra/
        ├── conventions/
        ├── adr/
        └── glossary/
```

Manual vault content such as `core/`, `raw/`, `investments_vault/` is read-only for this extension.

## Sidecar layout

Default sidecar:

```text
~/.pi/dreaming/
├── settings.json
├── meta.json
├── progress.tsv
└── .lock
```

Sidecar is operational state, not knowledge content.

## Card format

Cards use minimal frontmatter compatible with the existing `core/` style plus `dreaming_*` fields:

```markdown
---
title: "Prefer terse responses"
tags:
  - communication
  - dreaming
  - dreaming/feedback
aliases:
  - "no trailing summaries"
source: "[[/path/to/session.jsonl|session]]"
created: 2026-06-21
dreaming_id: usr_abc123
dreaming_type: feedback
dreaming_section: personal
dreaming_object_status: accepted
dreaming_evidence_status: valid
dreaming_extraction_confidence: high
dreaming_extraction_reasons:
  - exact_quote_match
dreaming_extraction_run: ext_...
dreaming_shared: false
dreaming_updated_at: 2026-06-21
dreaming_summary: "User wants no trailing summaries"
---

**Don't add trailing summaries to responses.**

**Why:** user can read the diff.

**How to apply:** end responses after actionable content.

## Evidence

> prefer terse responses without trailing summaries

_Source: /path/to/session.jsonl#entry-id_
```

## Git sync

If `gitSync: true`:

Before writing:

```bash
git -C <vault> pull --ff-only
```

After writing:

```bash
git -C <vault> add -- dreaming/
git -C <vault> commit -m "dreaming: ..."
git -C <vault> push
```

Safety rules:

- Only `dreaming/` is committed, not the whole vault.
- If `<vault>` is not a git repository, extraction fails closed.
- If `pull --ff-only` fails, extraction fails closed.
- “nothing to commit” is treated as OK.

## Troubleshooting

Check current status:

```text
/dream
```

Check settings:

```bash
cat ~/.pi/dreaming/settings.json
```

Check sidecar state:

```bash
cat ~/.pi/dreaming/meta.json
cat ~/.pi/dreaming/progress.tsv
```

Force rebuild indexes/manifest:

```text
/dream manifest
```

Disable git sync if git is blocking writes:

```text
/dream git-sync false
```

## Restore on a new machine

1. Install pi.
2. Put this extension directory into `~/.pi/agent/extensions/dreaming/`.
3. Create `~/.pi/dreaming/settings.json`:

   ```json
   {
     "schemaVersion": 1,
     "vault": "~/PATH/TO/KNOWLEDGE",
     "gitSync": true
   }
   ```

4. Ensure the vault exists and is a git repo if `gitSync: true`:

   ```bash
   cd ~/PATH/TO/KNOWLEDGE
   git status
   ```

5. Restart pi or run `/reload`.
6. Run `/dream` to verify paths.

## Development checks

This extension has no npm runtime dependencies besides packages already provided by pi (`@earendil-works/pi-coding-agent`, `@earendil-works/pi-ai`).

Basic load check:

```bash
node /tmp/dreaming-check.mjs
```

The check script is not part of the extension; it was used during development to import all TS modules through pi's jiti loader.
