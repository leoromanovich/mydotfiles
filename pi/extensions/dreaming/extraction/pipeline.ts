/**
 * Extraction pipeline.
 *
 * Решение 9: триггер на \`agent_end\` + gate (MIN_SLICE_CHARS).
 * Решение 10: модель = ctx.model (default active).
 * Решение 12: strict JSON (через prompt инструкцию); degraded-маркировка при parse-failure.
 * Решение 14: evidence span + quote validation (P7).
 * Решение 18: categorical confidence (high/medium/low/unknown).
 * Решение 22: обновление progress.tsv после run.
 *
 * MVP-упрощения (явные, доработать в фазе 2):
 *   - background runs: fire-and-forget (без полноценной run-очереди/cancel-tracket).
 *     Run id записывается в meta, но не хранится как отдельный run-файл.
 *   - acceptance gate (решение 13): MVP = всё auto-accept, но object_status помечается
 *     needs_review при evidence missing. Review queue — фаза 2.
 *   - validation issues (решение 19): пропускаем в MVP.
 */

import { complete, type UserMessage } from "@earendil-works/pi-ai";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { MAX_TRANSCRIPT_ENTRIES, MIN_SLICE_CHARS, resolvePaths } from "../config.ts";
import {
  acquireLock,
  atomicWrite,
  cardPath,
  ensureDirs,
  makeStableId,
  readCard,
  serializeMarkdown,
} from "../kb/io.ts";
import {
  EvidenceSpan,
  TranscriptLine,
  extractTranscript,
  formatTranscript,
  resolveQuote,
} from "./transcript.ts";
import { EXTRACTION_SYSTEM_PROMPT, buildExtractionUserPrompt } from "./prompt.ts";
import { updateMeta, appendProgress, refreshManifest } from "../kb/state.ts";
import { buildExtractionCard } from "../kb/card.ts";
import { gitCommitPushAfterWrite, gitPullBeforeWrite } from "../kb/git.ts";

interface ExtractionRaw {
  type: string;
  section: string;
  title: string;
  summary: string;
  body: string;
  tags?: string[];
  aliases?: string[];
  links?: string[];
  quote: string;
}

interface ExtractionResult {
  extractions: ExtractionRaw[];
  noop: boolean;
}

export interface RunOutcome {
  runId: string;
  status: "completed" | "degraded" | "noop" | "skipped" | "failed";
  reason?: string;
  saved: number;
  needsReview: number;
  errors: string[];
}

/** Gate: есть ли достаточно нового материала после курсора? */
function gateCheck(transcript: TranscriptLine[]): { ok: boolean; reason: string } {
  if (transcript.length === 0) return { ok: false, reason: "empty transcript" };
  const lastUserIdx = transcript.map((l) => l.role).lastIndexOf("user");
  if (lastUserIdx < 0) return { ok: false, reason: "no user message" };
  const text = formatTranscript(transcript);
  if (text.length < MIN_SLICE_CHARS) return { ok: false, reason: "slice too short" };
  return { ok: true, reason: "ok" };
}

/** Главный запуск extraction. Не бросает — возвращает RunOutcome. */
export async function runExtraction(pi: ExtensionAPI, ctx: ExtensionContext): Promise<RunOutcome> {
  const runId = `ext_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 6)}`;
  const errors: string[] = [];

  if (!ctx.model) {
    return { runId, status: "skipped", reason: "no active model", saved: 0, needsReview: 0, errors };
  }

  const paths = resolvePaths();
  ensureDirs(paths);

  // gate
  const fullTranscript = extractTranscript(ctx);
  const tail = fullTranscript.slice(-MAX_TRANSCRIPT_ENTRIES);
  const gate = gateCheck(tail);
  if (!gate.ok) {
    return { runId, status: "skipped", reason: gate.reason, saved: 0, needsReview: 0, errors };
  }

  // lock
  const release = acquireLock(paths.lockFile, "extraction");
  if (!release) {
    return { runId, status: "skipped", reason: "another run in progress", saved: 0, needsReview: 0, errors };
  }

  try {
    const transcriptText = formatTranscript(tail);
    const sessionFile = ctx.sessionManager.getSessionFile() ?? null;

    // Git sync before any write (fail-closed, решение: база актуальна перед изменением).
    const pull = gitPullBeforeWrite(paths);
    if (!pull.ok) {
      errors.push(`git pull failed: ${pull.message}${pull.output ? ` — ${pull.output}` : ""}`);
      updateMeta(paths, {
        lastExtractionAt: new Date().toISOString(),
        lastExtractionSessionId: sessionFile ?? undefined,
        lastExtractionStatus: "failed",
        lastExtractionRunId: runId,
        lastExtractionError: errors[errors.length - 1],
      });
      appendProgress(paths, sessionFile ?? "unknown", runId, "git-pull-failed", 1, new Date().toISOString().slice(0, 10));
      return { runId, status: "failed", reason: "git pull", saved: 0, needsReview: 0, errors };
    }

    // LLM call
    const auth = await ctx.modelRegistry.getApiKeyAndHeaders(ctx.model);
    if (!auth.ok || !auth.apiKey) {
      errors.push(auth.ok ? `no API key for ${ctx.model.provider}` : auth.error);
      return { runId, status: "failed", reason: "auth", saved: 0, needsReview: 0, errors };
    }

    const userMessage: UserMessage = {
      role: "user",
      content: [{ type: "text", text: buildExtractionUserPrompt(transcriptText) }],
      timestamp: Date.now(),
    };

    let response;
    try {
      response = await complete(
        ctx.model,
        { systemPrompt: EXTRACTION_SYSTEM_PROMPT, messages: [userMessage] },
        { apiKey: auth.apiKey, headers: auth.headers, signal: ctx.signal },
      );
    } catch (e) {
      errors.push(`LLM call failed: ${e instanceof Error ? e.message : String(e)}`);
      return { runId, status: "failed", reason: "llm", saved: 0, needsReview: 0, errors };
    }

    const raw = response.content
      .filter((c): c is { type: "text"; text: string } => c.type === "text")
      .map((c) => c.text)
      .join("\n")
      .trim();

    let parsed: ExtractionResult;
    let degraded = false;
    try {
      parsed = parseJsonLenient(raw);
    } catch (e) {
      degraded = true;
      errors.push(`JSON parse failed: ${e instanceof Error ? e.message : String(e)}`);
      // degraded mode: ничего не сохраняем, но записываем run как degraded
      updateMeta(paths, {
        lastExtractionAt: new Date().toISOString(),
        lastExtractionSessionId: sessionFile ?? undefined,
        lastExtractionStatus: "degraded",
        lastExtractionRunId: runId,
        lastExtractionError: errors[errors.length - 1],
      });
      appendProgress(paths, sessionFile ?? "unknown", runId, "degraded", 3, new Date().toISOString().slice(0, 10));
      return { runId, status: "degraded", reason: "json parse", saved: 0, needsReview: 0, errors };
    }

    if (parsed.noop || parsed.extractions.length === 0) {
      updateMeta(paths, {
        lastExtractionAt: new Date().toISOString(),
        lastExtractionSessionId: sessionFile ?? undefined,
        lastExtractionStatus: "noop",
        lastExtractionRunId: runId,
      });
      appendProgress(paths, sessionFile ?? "unknown", runId, "noop", 4, new Date().toISOString().slice(0, 10));
      return { runId, status: "noop", reason: "nothing durable", saved: 0, needsReview: 0, errors };
    }

    // apply extractions
    let saved = 0;
    let needsReview = 0;
    const typeMap: Record<string, string> = { user: "user", feedback: "feedback", project: "project", reference: "reference" };

    for (const ext of parsed.extractions) {
      const type = typeMap[ext.type] ?? "reference";
      const section = ext.section === "personal" ? "personal" : "knowledge";
      const id = makeStableId(type);

      // evidence validation (P7)
      const evMatch = resolveQuote(tail, sessionFile, ext.quote ?? "");
      const evidenceStatus: "valid" | "missing" = evMatch ? "valid" : "missing";
      const objectStatus: "accepted" | "needs_review" =
        evidenceStatus === "valid" ? "accepted" : "needs_review";

      // existing card with same title+section → upsert
      const targetPath = cardPath(paths, section, type, ext.title, id);
      const existing = readCard(targetPath);

      const card = buildExtractionCard({
        id,
        type,
        section,
        title: ext.title,
        summary: ext.summary,
        body: ext.body,
        tags: ext.tags,
        aliases: ext.aliases,
        links: ext.links,
        runId,
        sessionFile,
        evidenceSpan: evMatch?.span ?? null,
        quoteSnapshot: evMatch?.matched ?? ext.quote ?? "",
        evidenceStatus,
        objectStatus,
        shared: section === "knowledge",
        existing,
      });

      atomicWrite(targetPath, serializeMarkdown(card));
      if (objectStatus === "accepted") saved++;
      else needsReview++;
    }

    // refresh index + manifest + meta
    refreshManifest(paths);

    const push = gitCommitPushAfterWrite(paths, `dreaming: extract memories ${runId}`);
    if (!push.ok) {
      errors.push(`git push failed: ${push.message}${push.output ? ` — ${push.output}` : ""}`);
    }

    updateMeta(paths, {
      lastExtractionAt: new Date().toISOString(),
      lastExtractionSessionId: sessionFile ?? undefined,
      lastExtractionStatus: errors.length > 0 ? "degraded" : (degraded ? "degraded" : "updated"),
      lastExtractionRunId: runId,
      lastExtractionError: errors.length > 0 ? errors[errors.length - 1] : undefined,
    });
    appendProgress(paths, sessionFile ?? "unknown", runId, errors.length > 0 ? "degraded" : (degraded ? "degraded" : "done"), saved + needsReview, new Date().toISOString().slice(0, 10));

    const status: RunOutcome["status"] = errors.length > 0 || needsReview > 0 ? "degraded" : "completed";
    return { runId, status, saved, needsReview, errors };
  } finally {
    release();
  }
}

/**
 * Lenient JSON parser: убрать markdown-fences, взять первый {...} блок,
 * простить trailing commas. Бросает при полной неудаче.
 */
function parseJsonLenient(raw: string): ExtractionResult {
  let text = raw.trim();
  // strip ``` fences
  text = text.replace(/^```(?:json)?\s*/i, "").replace(/\s*```$/i, "");
  // strip leading/trailing non-json prose
  const firstBrace = text.indexOf("{");
  const lastBrace = text.lastIndexOf("}");
  if (firstBrace >= 0 && lastBrace > firstBrace) {
    text = text.slice(firstBrace, lastBrace + 1);
  }
  // trailing commas
  text = text.replace(/,(\s*[}\]])/g, "$1");

  const parsed = JSON.parse(text) as ExtractionResult;
  if (!parsed || typeof parsed !== "object") throw new Error("not an object");
  if (!Array.isArray(parsed.extractions)) throw new Error("missing extractions[]");
  return parsed;
}
