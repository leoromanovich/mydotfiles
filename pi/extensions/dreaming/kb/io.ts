/**
 * Path resolution, slugify, stable-id, frontmatter parse/serialize.
 * Без внешних зависимостей (решение P15: minimal frontmatter).
 */

import { existsSync, mkdirSync, readFileSync, renameSync, unlinkSync, writeFileSync } from "node:fs";
import { basename, dirname, join } from "node:path";
import { randomBytes } from "node:crypto";
import { KNOWLEDGE_SUBDIRS, TYPE_PREFIX, type Paths } from "../config.ts";

// ─── stable id ──────────────────────────────────────────────────────────────

/** Короткий stable id: 6 hex chars (решение 7). */
export function makeStableId(prefix: string): string {
  const hex = randomBytes(3).toString("hex"); // 6 chars
  return `${prefix}_${hex}`;
}

// ─── slugify ────────────────────────────────────────────────────────────────

// Минимальный transliteration map для кириллицы (без deps).
const CYRILLIC_MAP: Record<string, string> = {
  а: "a", б: "b", в: "v", г: "g", д: "d", е: "e", ё: "e", ж: "zh", з: "z",
  и: "i", й: "y", к: "k", л: "l", м: "m", н: "n", о: "o", п: "p", р: "r",
  с: "s", т: "t", у: "u", ф: "f", х: "h", ц: "ts", ч: "ch", ш: "sh",
  щ: "sch", ъ: "", ы: "y", ь: "", э: "e", ю: "yu", я: "ya",
};

/**
 * Slugify: транслитерация кириллицы → lowercase → kebab-case → trim/collapse.
 * Длина ограничена 60 символами для читаемости filename.
 */
export function slugify(input: string): string {
  let out = "";
  for (const ch of input.toLowerCase().trim()) {
    if (CYRILLIC_MAP[ch] !== undefined) {
      out += CYRILLIC_MAP[ch];
    } else if (CYRILLIC_MAP[ch.replace("ё", "е")] !== undefined) {
      out += CYRILLIC_MAP[ch.replace("ё", "е")];
    } else if (/[a-z0-9]/.test(ch)) {
      out += ch;
    } else if (/[\s_\-/.]/.test(ch)) {
      out += "-";
    }
    // остальные символы (пунктуация) — выкидываем
  }
  // collapse dashes + trim
  out = out.replace(/-+/g, "-").replace(/^-|-$/g, "");
  if (out.length > 60) out = out.slice(0, 60).replace(/-+$/, "");
  return out || "untitled";
}

// ─── filename / path ────────────────────────────────────────────────────────

/** Сконструировать путь карточки по section + type + title (решение 7). */
export function cardPath(paths: Paths, section: "personal" | "knowledge", type: string, title: string, id: string): string {
  const slug = slugify(title);
  // id уже содержит префикс (например "usr_abc123" от makeStableId).
  const filename = `${slug}__${id}.md`;

  if (section === "personal") {
    return join(paths.personalDir, filename);
  }

  // knowledge: распределяем по subdir'ам согласно типу
  let subdir = "infra";
  if (type === "people" || type === "reference") subdir = "people";
  else if (type === "repos" || type === "project") subdir = "repos";
  else if (KNOWLEDGE_SUBDIRS.includes(type as (typeof KNOWLEDGE_SUBDIRS)[number])) subdir = type;

  return join(paths.knowledgeDir, subdir, filename);
}

/** Все возможные родительские директории карточек (для ensureDirs). */
export function allCardDirs(paths: Paths): string[] {
  return [
    paths.personalDir,
    ...KNOWLEDGE_SUBDIRS.map((s) => join(paths.knowledgeDir, s)),
  ];
}

// ─── frontmatter (minimal YAML, без deps) ───────────────────────────────────

export interface Frontmatter {
  fields: Record<string, unknown>;
  body: string;
}

/** Парсить markdown с frontmatter `--- ... ---`. Без frontmatter — пустые fields. */
export function parseMarkdown(raw: string): Frontmatter {
  const match = raw.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n?([\s\S]*)$/);
  if (!match) return { fields: {}, body: raw };
  return { fields: parseSimpleYaml(match[1]), body: match[2] };
}

/** Минимальный YAML-парсер: строки, массивы, числа, bool. Без nested objects. */
function parseSimpleYaml(yaml: string): Record<string, unknown> {
  const fields: Record<string, unknown> = {};
  const lines = yaml.split(/\r?\n/);
  let i = 0;
  while (i < lines.length) {
    const line = lines[i];
    if (!line || line.trim().startsWith("#")) { i++; continue; }
    const m = line.match(/^(\S+):\s?(.*)$/);
    if (!m) { i++; continue; }
    const key = m[1];
    const val = m[2].trim();
    if (val === "") {
      // block array
      const items: string[] = [];
      i++;
      while (i < lines.length && /^\s+-\s+/.test(lines[i])) {
        const itemMatch = lines[i].match(/^\s+-\s+"?(.*?)"?\s*$/);
        if (itemMatch) items.push(itemMatch[1]);
        i++;
      }
      fields[key] = items;
      continue;
    }
    fields[key] = coerceScalar(val);
    i++;
  }
  return fields;
}

function coerceScalar(raw: string): unknown {
  // quoted string
  const q = raw.match(/^"(.*)"$/);
  if (q) return q[1];
  if (raw === "true") return true;
  if (raw === "false") return false;
  if (/^-?\d+$/.test(raw)) return Number(raw);
  return raw;
}

/** Сериализовать frontmatter + body обратно в markdown. */
export function serializeMarkdown(fm: Frontmatter): string {
  const yaml = serializeSimpleYaml(fm.fields);
  return `---\n${yaml}\n---\n\n${fm.body.trimStart()}`;
}

function serializeSimpleYaml(fields: Record<string, unknown>): string {
  const lines: string[] = [];
  for (const [key, val] of Object.entries(fields)) {
    if (Array.isArray(val)) {
      if (val.length === 0) {
        lines.push(`${key}: []`);
      } else {
        lines.push(`${key}:`);
        for (const item of val) lines.push(`  - ${yamlScalar(item)}`);
      }
    } else {
      lines.push(`${key}: ${yamlScalar(val)}`);
    }
  }
  return lines.join("\n");
}

function yamlScalar(val: unknown): string {
  if (typeof val === "string") {
    // quote if содержит спецсимволы или пустая
    if (val === "" || /[:\n#\[\]{}&'*!|>%@`,?"^\s]/.test(val)) {
      return `"${val.replace(/"/g, '\\"')}"`;
    }
    return val;
  }
  if (typeof val === "boolean" || typeof val === "number") return String(val);
  return `"${String(val)}"`;
}

// ─── atomic IO ──────────────────────────────────────────────────────────────

/** Atomic write: tmp-файл + rename. */
export function atomicWrite(filePath: string, content: string): void {
  const dir = dirname(filePath);
  mkdirSync(dir, { recursive: true });
  const tmp = join(dir, `.${basename(filePath)}.${process.pid}.tmp`);
  writeFileSync(tmp, content, "utf-8");
  renameSync(tmp, filePath);
}

/** Read markdown-файл как Frontmatter (если существует). */
export function readCard(filePath: string): Frontmatter | null {
  if (!existsSync(filePath)) return null;
  return parseMarkdown(readFileSync(filePath, "utf-8"));
}

/** JSON read/write (atomic). */
export function readJson<T>(filePath: string): T | null {
  if (!existsSync(filePath)) return null;
  try {
    return JSON.parse(readFileSync(filePath, "utf-8")) as T;
  } catch {
    return null;
  }
}

export function writeJsonAtomic<T>(filePath: string, data: T): void {
  atomicWrite(filePath, JSON.stringify(data, null, 2) + "\n");
}

// ─── file-lock (решение 17) ──────────────────────────────────────────────────

/**
 * Простой lock-файл с PID + heartbeat-таймстампом.
 * Не использует flock — кросс-платформенный. Stale если PID мёртв или >5мин.
 */
export function acquireLock(lockFile: string, label: string): (() => void) | null {
  if (existsSync(lockFile)) {
    try {
      const existing = JSON.parse(readFileSync(lockFile, "utf-8"));
      const age = Date.now() - (existing.heartbeat ?? existing.acquiredAt ?? 0);
      const stale = age > 5 * 60 * 1000;
      if (!stale && existing.pid !== process.pid) {
        // проверим жив ли процесс
        try { process.kill(existing.pid, 0); return null; } catch { /* мёртв — забираем */ }
      }
    } catch { /* битый lock — перезаписываем */ }
  }
  const payload = { pid: process.pid, label, acquiredAt: Date.now(), heartbeat: Date.now() };
  atomicWrite(lockFile, JSON.stringify(payload));
  const refresh = setInterval(() => {
    try { writeJsonAtomic(lockFile, { ...payload, heartbeat: Date.now() }); } catch { /* ignore */ }
  }, 30_000);
  refresh.unref?.();
  return () => {
    clearInterval(refresh);
    try {
      const cur = JSON.parse(readFileSync(lockFile, "utf-8"));
      if (cur.pid === process.pid) {
        unlinkSync(lockFile);
      }
    } catch { /* ignore */ }
  };
}

/** Ensure dreaming dir structure exists for the given profile. */
export function ensureDirs(paths: Paths): void {
  mkdirSync(paths.dreamingRoot, { recursive: true });
  for (const d of allCardDirs(paths)) mkdirSync(d, { recursive: true });
}
