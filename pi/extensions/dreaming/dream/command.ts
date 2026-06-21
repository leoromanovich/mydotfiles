/**
 * `/dream` command — MVP.
 *
 * Решение 15: ручной запуск, без автоматов.
 * Решение 16: in-process dream с JSON-output — фаза 2. В MVP /dream показывает
 *             статистику KB и последний dream, давая пользователю контрольную точку.
 *
 * Subcommands:
 *   /dream              — показать статус KB (vault, карточки, последние runs)
 *   /dream path <path>       — установить путь к базе знаний (пишет в settings.json)
 *   /dream git-sync [bool]   — показать/включить/выключить git pull+commit+push
 *   /dream accept <id>       — (заглушка) принять needs_review карточку
 *   /dream manifest          — принудительно пересобрать _manifest.json и _index.md
 */

import type { ExtensionCommandContext } from "@earendil-works/pi-coding-agent";
import { loadSettings, resolvePaths, saveSettings, shortPath } from "../config.ts";
import { getStats, readMeta, refreshManifest } from "../kb/state.ts";
import { gitCommitPushAfterWrite, gitPullBeforeWrite } from "../kb/git.ts";

function fmtDate(iso?: string): string {
  if (!iso) return "никогда";
  try {
    const d = new Date(iso);
    return d.toLocaleString("ru-RU", { dateStyle: "medium", timeStyle: "short" });
  } catch {
    return iso;
  }
}

export async function dreamCommand(args: string | undefined, ctx: ExtensionCommandContext): Promise<void> {
  const parts = (args ?? "").trim().split(/\s+/).filter(Boolean);
  const sub = parts[0] ?? "";

  // /dream path <path>
  if (sub === "path") {
    const value = parts[1];
    if (!value) {
      // показать текущий
      const s = loadSettings();
      const cur = s.vault ? shortPath(s.vault) : "(default: ~/Documents/Zettel/Knowledge)";
      if (ctx.hasUI) ctx.ui.notify(`Текущий путь к базе:\n  ${cur}\n\nУстановить: /dream path <путь>`, "info");
      return;
    }
    try {
      const s = loadSettings();
      s.vault = value; // expandTilde сработает при loadSettings на следующем чтении
      saveSettings(s);
      const paths = resolvePaths();
      if (ctx.hasUI) {
        ctx.ui.notify(
          `База знаний dreaming:\n  vault:   ${shortPath(paths.vaultRoot)}\n  sidecar: ${shortPath(paths.sidecarRoot)}`,
          "info",
        );
      }
    } catch (e) {
      if (ctx.hasUI) ctx.ui.notify(e instanceof Error ? e.message : String(e), "error");
    }
    return;
  }

  if (sub === "git-sync") {
    const value = parts[1];
    const s = loadSettings();
    if (!value) {
      if (ctx.hasUI) ctx.ui.notify(`gitSync: ${s.gitSync === true ? "true" : "false"}\nВключить: /dream git-sync true\nВыключить: /dream git-sync false`, "info");
      return;
    }
    const normalized = value.toLowerCase();
    if (!["true", "false", "1", "0", "yes", "no", "on", "off"].includes(normalized)) {
      if (ctx.hasUI) ctx.ui.notify("Используй: /dream git-sync true|false", "error");
      return;
    }
    s.gitSync = /^(true|1|yes|on)$/.test(normalized);
    saveSettings(s);
    if (ctx.hasUI) ctx.ui.notify(`gitSync: ${s.gitSync ? "true" : "false"}`, "info");
    return;
  }

  const paths = resolvePaths();

  if (sub === "manifest") {
    const pull = gitPullBeforeWrite(paths);
    if (!pull.ok) {
      if (ctx.hasUI) ctx.ui.notify(`git pull failed: ${pull.message}${pull.output ? `\n${pull.output}` : ""}`, "error");
      return;
    }
    refreshManifest(paths);
    const push = gitCommitPushAfterWrite(paths, "dreaming: refresh manifest");
    if (!push.ok) {
      if (ctx.hasUI) ctx.ui.notify(`Manifest пересобран, но git push failed: ${push.message}${push.output ? `\n${push.output}` : ""}`, "warning");
      return;
    }
    if (ctx.hasUI) ctx.ui.notify("Manifest и _index.md пересобраны", "info");
    return;
  }

  if (sub === "accept") {
    if (ctx.hasUI) ctx.ui.notify("/dream accept — будет реализован в фазе 2 (review queue)", "warning");
    return;
  }

  // default + "stats": показать статус
  const stats = getStats(paths);
  const meta = readMeta(paths);

  const lines: string[] = [
    "Dreaming KB",
    `  vault:   ${shortPath(paths.vaultRoot)}`,
    `  sidecar: ${shortPath(paths.sidecarRoot)}`,
    `  gitSync: ${paths.gitSync ? "true" : "false"}`,
    "",
    `${stats.totalCards} карточек`,
    `  accepted: ${stats.accepted}  •  needs_review: ${stats.needsReview}`,
    `  personal: ${stats.personal}  •  knowledge: ${stats.knowledge}`,
  ];
  if (Object.keys(stats.byType).length > 0) {
    lines.push("", "По типам:");
    for (const [t, n] of Object.entries(stats.byType).sort((a, b) => b[1] - a[1])) {
      lines.push(`  ${t}: ${n}`);
    }
  }
  lines.push("");
  lines.push(`Последний extraction: ${fmtDate(meta.lastExtractionAt)} (${meta.lastExtractionStatus ?? "-"})`);
  lines.push(`Последний dream:      ${fmtDate(meta.lastDreamAt)} (${meta.lastDreamStatus ?? "-"})`);
  if (meta.lastExtractionError) lines.push(`Ошибка extraction: ${meta.lastExtractionError}`);
  lines.push("");
  lines.push("Команды: /dream path <путь> · /dream git-sync true|false · /dream manifest · /dream stats");
  lines.push("_Полноценный dream (merge/dedup/fix-stale) — фаза 2._");

  if (ctx.hasUI) {
    ctx.ui.notify(lines.join("\n"), "info");
  } else {
    console.log(lines.join("\n"));
  }
}
