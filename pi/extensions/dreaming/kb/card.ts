/**
 * Card builder (frontmatter + body markdown).
 * Решение 4: формат `core/` + dreaming_* машинные поля.
 * Решение 6: object_status ≠ evidence_status.
 * Решение 18: categorical confidence.
 */

import type { Frontmatter } from "./io.ts";
import type { EvidenceSpan } from "../extraction/transcript.ts";

interface BuildArgs {
  id: string;
  type: string;
  section: "personal" | "knowledge";
  title: string;
  summary: string;
  body: string;
  tags?: string[];
  aliases?: string[];
  links?: string[];
  runId: string;
  sessionFile: string | null;
  evidenceSpan: EvidenceSpan | null;
  quoteSnapshot: string;
  evidenceStatus: "valid" | "missing" | "stale" | "invalid";
  objectStatus: "candidate" | "needs_review" | "accepted" | "rejected";
  shared: boolean;
  existing?: Frontmatter | null;
}

const ISO = () => new Date().toISOString();
const DATE = () => ISO().slice(0, 10);

/** Confidence: MVP heuristic — valid evidence → high, missing → low. Фаза 2: model-supplied. */
function inferConfidence(evidenceStatus: BuildArgs["evidenceStatus"]): {
  level: "high" | "medium" | "low" | "unknown";
  reasons: string[];
} {
  if (evidenceStatus === "valid") return { level: "high", reasons: ["exact_quote_match"] };
  return { level: "low", reasons: ["quote_not_found_in_transcript"] };
}

export function buildExtractionCard(args: BuildArgs): Frontmatter {
  const conf = inferConfidence(args.evidenceStatus);

  // preserve created/at from existing card on upsert
  const createdAt = (args.existing?.fields.created as string) ?? DATE();
  const updatedAt = DATE();

  const fields: Record<string, unknown> = {
    title: args.title,
    tags: dedupe([...(args.tags ?? []), "dreaming", `dreaming/${args.type}`]),
    aliases: args.aliases ?? [],
    source: args.sessionFile ? `[[${args.sessionFile}|session]]` : "",
    created: createdAt,

    // dreaming_* machine fields (решение 4)
    dreaming_id: args.id,
    dreaming_type: args.type,
    dreaming_section: args.section,
    dreaming_object_status: args.objectStatus,
    dreaming_evidence_status: args.evidenceStatus,
    dreaming_extraction_confidence: conf.level,
    dreaming_extraction_reasons: conf.reasons,
    dreaming_extraction_run: args.runId,
    dreaming_shared: args.shared,
    dreaming_updated_at: updatedAt,
  };

  if (args.summary) fields.dreaming_summary = args.summary;

  // body: user-facing markdown
  const linksBlock = args.links && args.links.length > 0
    ? `\n\n## Links\n\n${args.links.map((l) => `- ${l}`).join("\n")}\n`
    : "";

  const evidenceBlock = args.evidenceStatus === "valid" && args.quoteSnapshot
    ? `\n\n## Evidence\n\n> ${args.quoteSnapshot.replace(/\n/g, "\n> ")}\n\n_Source: ${args.evidenceSpan?.sessionFile ?? "?"}#${args.evidenceSpan?.entryId ?? "?"}_\n`
    : args.evidenceStatus !== "valid"
      ? `\n\n## Evidence\n\n_${args.evidenceStatus} evidence — needs review_\n`
      : "";

  const body = `${args.body.trim()}${evidenceBlock}${linksBlock}\n`;
  return { fields, body };
}

function dedupe(arr: string[]): string[] {
  return [...new Set(arr.filter(Boolean))];
}
