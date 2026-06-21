/**
 * Dreaming extension — paths configuration.
 *
 * Один настраиваемый путь к базе знаний (vault). Актуально для сценария
 * «разные компьютеры — разные пути»: на каждой машине свой settings.json
 * (или env), dreaming пишет туда.
 *
 * Пути резолвятся per-call (threading через Paths) — нет глобального mutable state.
 *
 * Решения: dreaming-decisions.md (решение 1 + решение 28-коррекция).
 */

import { existsSync, mkdirSync, readFileSync, renameSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

// ─── constants ──────────────────────────────────────────────────────────────

/** Корень config-директории dreaming (settings + sidecar по умолчанию). */
export const CONFIG_DIR = join(homedir(), ".pi", "dreaming");
export const SETTINGS_FILE = join(CONFIG_DIR, "settings.json");

/** Subdir внутри vault, куда dreaming рендерит карточки. */
export const DREAMING_DIRNAME = "dreaming";

export const KNOWLEDGE_SUBDIRS = ["people", "repos", "infra", "conventions", "adr", "glossary"] as const;
export const INDEX_FILENAME = "_index.md";
export const MANIFEST_FILENAME = "_manifest.json";
export const META_FILENAME = "meta.json";
export const LOCK_FILENAME = ".lock";
export const PROGRESS_FILENAME = "progress.tsv";

/** Gate для extraction (решение 9): минимальная длина slice транскрипта. */
export const MIN_SLICE_CHARS = 500;

/** Максимальное число записей транскрипта, отправляемых в extraction. */
export const MAX_TRANSCRIPT_ENTRIES = 40;

/** Префиксы stable-id по типу карточки (решение 7). */
export const TYPE_PREFIX: Record<string, string> = {
  user: "usr",
  feedback: "usr", // feedback → personal/, тот же prefix
  project: "prj",
  reference: "ref",
  // finer-grained внутри knowledge/
  people: "ent",
  repos: "repo",
  infra: "ref",
  conventions: "conv",
  adr: "adr",
  glossary: "gls",
};

const DEFAULT_VAULT = join(homedir(), "Documents", "Zettel", "Knowledge");

// ─── types ──────────────────────────────────────────────────────────────────

export interface Settings {
  schemaVersion: number;
  /** Корень canonical vault (Obsidian vault пользователя). */
  vault?: string;
  /** Корень sidecar state (default: ~/.pi/dreaming). */
  sidecar?: string;
  /** Если true: перед записью git pull --ff-only, после записи commit+push dreaming/. */
  gitSync?: boolean;
}

/** Все пути, производные от vault+sidecar. Передаётся в kb/* функции. */
export interface Paths {
  vaultRoot: string;
  dreamingRoot: string; // vaultRoot/dreaming
  personalDir: string;
  knowledgeDir: string;
  sidecarRoot: string;
  metaFile: string;
  lockFile: string;
  progressFile: string;
  manifestFile: string;
  gitSync: boolean;
}

// ─── settings IO ────────────────────────────────────────────────────────────

const DEFAULT_SETTINGS: Settings = { schemaVersion: 1 };

export function expandTilde(p: string): string {
  if (p === "~") return homedir();
  if (p.startsWith("~/")) return join(homedir(), p.slice(2));
  return p;
}

export function loadSettings(): Settings {
  if (!existsSync(SETTINGS_FILE)) return { ...DEFAULT_SETTINGS };
  try {
    const raw = JSON.parse(readFileSync(SETTINGS_FILE, "utf-8")) as Settings;
    const out: Settings = { schemaVersion: raw.schemaVersion ?? 1 };
    if (typeof raw.vault === "string") out.vault = expandTilde(raw.vault);
    if (typeof raw.sidecar === "string") out.sidecar = expandTilde(raw.sidecar);
    if (typeof raw.gitSync === "boolean") out.gitSync = raw.gitSync;
    return out;
  } catch {
    return { ...DEFAULT_SETTINGS };
  }
}

export function saveSettings(s: Settings): void {
  mkdirSync(CONFIG_DIR, { recursive: true });
  const tmp = join(CONFIG_DIR, `.settings.${process.pid}.tmp`);
  writeFileSync(tmp, JSON.stringify(s, null, 2) + "\n", "utf-8");
  renameSync(tmp, SETTINGS_FILE);
}

// ─── path resolution ────────────────────────────────────────────────────────

/**
 * Разрезолвить пути по приоритету:
 *   1. env DREAMING_VAULT_ROOT (+ optional DREAMING_SIDECAR_ROOT) — ad-hoc, для тестов
 *   2. settings.json vault/sidecar/gitSync
 *   3. default (vault = ~/Documents/Zettel/Knowledge)
 */
export function resolvePaths(): Paths {
  const settings = loadSettings();

  const vault = process.env.DREAMING_VAULT_ROOT
    ? expandTilde(process.env.DREAMING_VAULT_ROOT)
    : settings.vault ?? DEFAULT_VAULT;

  const sidecar = process.env.DREAMING_SIDECAR_ROOT
    ? expandTilde(process.env.DREAMING_SIDECAR_ROOT)
    : settings.sidecar ?? CONFIG_DIR;

  const gitSync = process.env.DREAMING_GIT_SYNC !== undefined
    ? /^(1|true|yes|on)$/i.test(process.env.DREAMING_GIT_SYNC)
    : settings.gitSync === true;

  return buildPaths(vault, sidecar, gitSync);
}

function buildPaths(vault: string, sidecar: string, gitSync: boolean): Paths {
  const dreamingRoot = join(vault, DREAMING_DIRNAME);
  return {
    vaultRoot: vault,
    dreamingRoot,
    personalDir: join(dreamingRoot, "personal"),
    knowledgeDir: join(dreamingRoot, "knowledge"),
    sidecarRoot: sidecar,
    metaFile: join(sidecar, META_FILENAME),
    lockFile: join(sidecar, LOCK_FILENAME),
    progressFile: join(sidecar, PROGRESS_FILENAME),
    manifestFile: join(dreamingRoot, MANIFEST_FILENAME),
    gitSync,
  };
}

/** Короткая форма для отображения в UI (~ вместо $HOME). */
export function shortPath(p: string): string {
  const home = homedir();
  if (p === home || p.startsWith(home + "/")) return "~" + p.slice(home.length);
  return p;
}
