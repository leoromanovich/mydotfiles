/**
 * Transcript helpers: session entries → текст для extraction-промпта,
 * плюс резолв quote → evidence span (P7).
 */

import type { ExtensionContext } from "@earendil-works/pi-coding-agent";

type ContentBlock = { type?: string; text?: string; name?: string; arguments?: Record<string, unknown> };

export interface TranscriptLine {
  role: "user" | "assistant";
  text: string;
  /** Session entry id для evidence span (P7). */
  entryId?: string;
}

export interface EvidenceSpan {
  /** Файл сессии. */
  sessionFile: string | null;
  /** ID entry в session manager. */
  entryId?: string;
  /** Char offsets внутри текстовой части entry. */
  charStart: number;
  charEnd: number;
}

/**
 * Извлечь user/assistant строки из branch сессии.
 * Возвращает только text + summary tool calls (как summarize.ts).
 */
export function extractTranscript(ctx: ExtensionContext): TranscriptLine[] {
  const branch = ctx.sessionManager.getBranch();
  const lines: TranscriptLine[] = [];

  for (const entry of branch) {
    if (entry.type !== "message") continue;
    const msg = entry.message as { role?: string; content?: unknown };
    if (!msg.role) continue;

    const role = msg.role;
    if (role !== "user" && role !== "assistant") continue;

    const textParts = extractTextParts(msg.content);
    const toolCallLines = role === "assistant" ? extractToolCallLines(msg.content) : [];

    const text = [...textParts, ...toolCallLines].join("\n").trim();
    if (text.length === 0) continue;

    lines.push({ role, text, entryId: entry.id });
  }

  return lines;
}

function extractTextParts(content: unknown): string[] {
  if (typeof content === "string") return [content];
  if (!Array.isArray(content)) return [];
  const out: string[] = [];
  for (const part of content) {
    if (!part || typeof part !== "object") continue;
    const b = part as ContentBlock;
    if (b.type === "text" && typeof b.text === "string") out.push(b.text);
  }
  return out;
}

function extractToolCallLines(content: unknown): string[] {
  if (!Array.isArray(content)) return [];
  const out: string[] = [];
  for (const part of content) {
    if (!part || typeof part !== "object") continue;
    const b = part as ContentBlock;
    if (b.type !== "toolCall" || typeof b.name !== "string") continue;
    out.push(`Tool ${b.name} called with ${JSON.stringify(b.arguments ?? {})}`);
  }
  return out;
}

/** Сериализовать транскрипт в текст для промпта. */
export function formatTranscript(lines: TranscriptLine[]): string {
  return lines.map((l) => `${l.role === "user" ? "User" : "Assistant"}:\n${l.text}`).join("\n\n---\n\n");
}

/**
 * Резолвить цитату в evidence span. Ищем дословное совпадение в тексте entry.
 * Возвращает null если не найдено (→ evidence_status: missing).
 * Допускается цитата с одним `[...]`-пропуском.
 */
export function resolveQuote(
  transcript: TranscriptLine[],
  sessionFile: string | null,
  quote: string,
): { span: EvidenceSpan; matched: string } | null {
  const q = quote.trim();
  if (!q) return null;

  for (const line of transcript) {
    const text = line.text;
    const idx = text.indexOf(q);
    if (idx >= 0) {
      return {
        span: {
          sessionFile,
          entryId: line.entryId,
          charStart: idx,
          charEnd: idx + q.length,
        },
        matched: q,
      };
    }
    // Fuzzy: одно `[...]`-пропуск
    if (q.includes("[...]")) {
      const parts = q.split("[...]").map((p) => p.trim());
      if (parts.length === 2 && parts[0] && parts[1]) {
        const i0 = text.indexOf(parts[0]);
        if (i0 >= 0) {
          const rest = text.slice(i0 + parts[0].length);
          const i1 = rest.indexOf(parts[1]);
          if (i1 >= 0) {
            return {
              span: {
                sessionFile,
                entryId: line.entryId,
                charStart: i0,
                charEnd: i0 + parts[0].length + i1 + parts[1].length,
              },
              matched: text.slice(i0, i0 + parts[0].length + i1 + parts[1].length),
            };
          }
        }
      }
    }
  }
  return null;
}
