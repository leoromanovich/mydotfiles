/**
 * Dreaming extension — entry point.
 *
 * Architecture: see reports/dreaming-extension-plan.md + reports/dreaming-decisions.md.
 *
 * Phase 1 (MVP):
 *   - Extraction on `agent_end` (решение 9): durable facts → Knowledge/dreaming/.
 *   - `/dream` status command (решение 15): показывает статистику KB.
 *
 * Manual vault cards (core/, investments_vault/) — read-only для dreaming (решение 1).
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { ensureDirs } from "./kb/io.ts";
import { resolvePaths } from "./config.ts";
import { runExtraction } from "./extraction/pipeline.ts";
import { dreamCommand } from "./dream/command.ts";

export default function dreaming(pi: ExtensionAPI) {
  // Лучше ensureDirs на session_start — на случай если агент стартует без extraction.
  pi.on("session_start", async (_event, ctx) => {
    try {
      const paths = resolvePaths();
      ensureDirs(paths);
    } catch (e) {
      console.error("[dreaming] ensureDirs failed:", e);
    }
  });

  // Extraction на agent_end (решение 9). Fire-and-forget background (решение 11/P12).
  pi.on("agent_end", async (_event, ctx) => {
    // Не блокируем agent loop. Фоновый запуск, ошибка — в notify.
    runExtraction(pi, ctx)
      .then((outcome) => {
        if (!ctx.hasUI) return;
        if (outcome.status === "completed" && outcome.saved > 0) {
          ctx.ui.notify(
            `Dreaming: извлечено ${outcome.saved} ${cardWord(outcome.saved)}`,
            "info",
          );
          ctx.ui.setStatus("dreaming", `last ext: +${outcome.saved}`);
        } else if (outcome.status === "degraded" && outcome.needsReview > 0) {
          ctx.ui.notify(
            `Dreaming: ${outcome.needsReview} карточек требуют ревью (evidence missing)`,
            "warning",
          );
        } else if (outcome.status === "failed") {
          ctx.ui.notify(
            `Dreaming extraction failed: ${outcome.reason ?? outcome.errors[0] ?? "unknown"}`,
            "error",
          );
        }
        // skipped/noop — молча
      })
      .catch((e) => {
        console.error("[dreaming] extraction crashed:", e);
        if (ctx.hasUI) {
          ctx.ui.notify(`Dreaming: internal error — ${e instanceof Error ? e.message : String(e)}`, "error");
        }
      });
  });

  pi.registerCommand("dream", {
    description: "Dreaming KB: статус и управление долговременной памятью",
    handler: async (args, ctx) => {
      await dreamCommand(args, ctx);
    },
  });
}

function cardWord(n: number): string {
  const mod10 = n % 10;
  const mod100 = n % 100;
  if (mod10 === 1 && mod100 !== 11) return "карточка";
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20)) return "карточки";
  return "карточек";
}
