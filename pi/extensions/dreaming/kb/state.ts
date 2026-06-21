/**
 * Sidecar state: meta.json, progress.tsv, manifest.
 * Решение 1: sidecar вне vault (в ~/.pi/dreaming/data/<profile>/).
 * Решение 5: vault = repeatable render из sidecar canonical.
 * Решение 8: immutable revisions (фаза 2; MVP оставлены placeholder-функции).
 * Решение 20: run provenance.
 * Решение 22: progress.tsv.
 * Решение 23: manifest refresh батчово.
 *
 * Все функции принимают `paths: Paths` (threading вместо глобального state).
 */

import { appendFileSync, existsSync, readFileSync, readdirSync, statSync } from "node:fs";
import { createHash } from "node:crypto";
import { basename, join, relative } from "node:path";
import type { Paths } from "../config.ts";
import { atomicWrite, parseMarkdown, readCard, readJson, writeJsonAtomic } from "./io.ts";

// ─── meta.json ──────────────────────────────────────────────────────────────

export interface Meta {
  schemaVersion: number;
  lastExtractionAt?: string;
  lastExtractionSessionId?: string;
  lastExtractionStatus?: "updated" | "noop" | "degraded" | "failed";
  lastExtractionRunId?: string;
  lastExtractionError?: string;
  lastDreamAt?: string;
  lastDreamStatus?: "updated" | "noop" | "degraded" | "failed";
  lastDreamRunId?: string;
  lastDreamSummary?: string;
  recentExtractionStats?: { saved?: number; needsReview?: number };
}

const DEFAULT_META: Meta = { schemaVersion: 1 };

export function readMeta(paths: Paths): Meta {
  return readJson<Meta>(paths.metaFile) ?? { ...DEFAULT_META };
}

export function updateMeta(paths: Paths, patch: Partial<Meta>): void {
  const cur = readMeta(paths);
  const next = { ...cur, ...patch };
  if (!next.schemaVersion) next.schemaVersion = 1;
  writeJsonAtomic(paths.metaFile, next);
}

// ─── progress.tsv (решение 22) ──────────────────────────────────────────────
// Формат как Knowledge/_progress.tsv: source<TAB>id<TAB>status<TAB>priority<TAB>date

export function appendProgress(
  paths: Paths,
  source: string,
  id: string,
  status: string,
  priority: number,
  date: string,
): void {
  const line = [source, id, status, String(priority), date].join("\t") + "\n";
  appendFileSync(paths.progressFile, line, "utf-8");
}

export function readProgress(paths: Paths): Array<{ source: string; id: string; status: string; priority: number; date: string }> {
  if (!existsSync(paths.progressFile)) return [];
  return readFileSync(paths.progressFile, "utf-8")
    .split("\n")
    .filter(Boolean)
    .map((line: string) => {
      const [source, id, status, priority, date] = line.split("\t");
      return { source, id, status, priority: Number(priority) || 0, date };
    });
}

// ─── _index.md (per-section) ────────────────────────────────────────────────

/** Перестроить _index.md для каждого раздела. */
export function rebuildIndexes(paths: Paths): void {
  buildIndex(paths, paths.personalDir, "Personal");
  buildIndex(paths, paths.knowledgeDir, "Knowledge");
}

function buildIndex(paths: Paths, dir: string, label: string): void {
  const entries = listCards(dir);
  const lines: string[] = [`# ${label} dreaming index`, "", `_Автогенерируется. Последнее обновление: ${new Date().toISOString()}_`, ""];

  if (entries.length === 0) {
    lines.push("_Пусто._");
  } else {
    lines.push("| Card | Type | Status | Evidence | Updated |", "|---|---|---|---|---|");
    for (const e of entries) {
      const title = String(e.fm.title ?? basename(e.path, ".md"));
      const rel = relative(paths.dreamingRoot, e.path).replace(/\.md$/, "");
      const type = String(e.fm.dreaming_type ?? "-");
      const objStatus = String(e.fm.dreaming_object_status ?? "-");
      const evStatus = String(e.fm.dreaming_evidence_status ?? "-");
      const upd = String(e.fm.dreaming_updated_at ?? "-");
      lines.push(`| [[${rel}|${title}]] | ${type} | ${objStatus} | ${evStatus} | ${upd} |`);
    }
  }
  atomicWrite(join(dir, "_index.md"), lines.join("\n") + "\n");
}

function listCards(dir: string): Array<{ path: string; fm: Record<string, unknown> }> {
  if (!existsSync(dir)) return [];
  const out: Array<{ path: string; fm: Record<string, unknown> }> = [];
  const walk = (d: string) => {
    for (const name of readdirSync(d)) {
      if (name.startsWith(".") || name.startsWith("_")) continue;
      const p = join(d, name);
      const s = statSync(p);
      if (s.isDirectory()) walk(p);
      else if (name.endsWith(".md")) {
        const card = readCard(p);
        if (card) out.push({ path: p, fm: card.fields });
      }
    }
  };
  walk(dir);
  return out;
}

// ─── manifest.json (решение 23) ─────────────────────────────────────────────
// Батчовый refresh: вызывается из extraction/dream/accept-command.

export interface ManifestEntry {
  dreaming_id: string;
  type: string;
  section: "personal" | "knowledge";
  path: string; // относительный путь от dreamingRoot
  object_status: string;
  evidence_status: string;
  content_hash: string;
  dreaming_extraction_run?: string;
}

export interface Manifest {
  exporter_version: string;
  schema_version: number;
  exported_at: string;
  files: ManifestEntry[];
}

const MANIFEST_VERSION = "0.1.0";

export function refreshManifest(paths: Paths): void {
  rebuildIndexes(paths);
  const files: ManifestEntry[] = [];

  const collect = (section: "personal" | "knowledge", rootDir: string) => {
    if (!existsSync(rootDir)) return;
    const walk = (d: string) => {
      for (const name of readdirSync(d)) {
        if (name.startsWith(".") || name.startsWith("_")) continue;
        const p = join(d, name);
        const s = statSync(p);
        if (s.isDirectory()) walk(p);
        else if (name.endsWith(".md")) {
          const raw = readFileSync(p, "utf-8");
          const fm = parseMarkdown(raw).fields;
          const hash = createHash("sha256").update(raw).digest("hex").slice(0, 16);
          files.push({
            dreaming_id: String(fm.dreaming_id ?? basename(p, ".md")),
            type: String(fm.dreaming_type ?? "unknown"),
            section,
            path: relative(paths.dreamingRoot, p),
            object_status: String(fm.dreaming_object_status ?? "accepted"),
            evidence_status: String(fm.dreaming_evidence_status ?? "valid"),
            content_hash: hash,
            dreaming_extraction_run: fm.dreaming_extraction_run as string | undefined,
          });
        }
      }
    };
    walk(rootDir);
  };

  collect("personal", paths.personalDir);
  collect("knowledge", paths.knowledgeDir);

  const manifest: Manifest = {
    exporter_version: MANIFEST_VERSION,
    schema_version: 1,
    exported_at: new Date().toISOString(),
    files,
  };
  writeJsonAtomic(paths.manifestFile, manifest);
}

// ─── stats for /dream command ───────────────────────────────────────────────

export interface KbStats {
  totalCards: number;
  accepted: number;
  needsReview: number;
  personal: number;
  knowledge: number;
  byType: Record<string, number>;
  lastExtraction?: string;
  lastDream?: string;
}

export function getStats(paths: Paths): KbStats {
  const m = readMeta(paths);
  const byType: Record<string, number> = {};
  let total = 0, accepted = 0, needsReview = 0, personal = 0, knowledge = 0;

  const count = (section: "personal" | "knowledge", dir: string) => {
    if (!existsSync(dir)) return;
    const walk = (d: string) => {
      for (const name of readdirSync(d)) {
        if (name.startsWith(".") || name.startsWith("_")) continue;
        const p = join(d, name);
        const s = statSync(p);
        if (s.isDirectory()) walk(p);
        else if (name.endsWith(".md")) {
          total++;
          if (section === "personal") personal++; else knowledge++;
          const fm = readCard(p).fields;
          const t = String(fm.dreaming_type ?? "unknown");
          byType[t] = (byType[t] ?? 0) + 1;
          if (fm.dreaming_object_status === "accepted") accepted++;
          else if (fm.dreaming_object_status === "needs_review") needsReview++;
        }
      }
    };
    walk(dir);
  };

  count("personal", paths.personalDir);
  count("knowledge", paths.knowledgeDir);

  return {
    totalCards: total,
    accepted,
    needsReview,
    personal,
    knowledge,
    byType,
    lastExtraction: m.lastExtractionAt,
    lastDream: m.lastDreamAt,
  };
}
