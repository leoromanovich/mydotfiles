/** Git sync for dreaming vault.
 *
 * If paths.gitSync === true:
 *   before write: git pull --ff-only
 *   after write:  git add -- dreaming/ && git commit && git push
 *
 * Safety:
 * - Fixed `git` command + argv arrays, no shell.
 * - Commit only `dreaming/`, not user's whole vault.
 * - Pull is fail-closed: if repo/pull fails, caller should not write.
 */

import { spawnSync } from "node:child_process";
import { relative } from "node:path";
import type { Paths } from "../config.ts";

export interface GitSyncResult {
  ok: boolean;
  skipped?: boolean;
  message: string;
  output?: string;
}

function runGit(paths: Paths, args: string[]): GitSyncResult {
  const r = spawnSync("git", ["-C", paths.vaultRoot, ...args], {
    encoding: "utf-8",
    timeout: 120_000,
  });
  const output = [r.stdout, r.stderr].filter(Boolean).join("\n").trim();
  if (r.error) return { ok: false, message: r.error.message, output };
  if (r.status !== 0) return { ok: false, message: `git ${args.join(" ")} failed (${r.status})`, output };
  return { ok: true, message: "ok", output };
}

export function isGitRepo(paths: Paths): boolean {
  const r = runGit(paths, ["rev-parse", "--is-inside-work-tree"]);
  return r.ok && r.output?.trim() === "true";
}

export function gitPullBeforeWrite(paths: Paths): GitSyncResult {
  if (!paths.gitSync) return { ok: true, skipped: true, message: "gitSync disabled" };
  if (!isGitRepo(paths)) {
    return { ok: false, message: `vault is not a git repository: ${paths.vaultRoot}` };
  }
  return runGit(paths, ["pull", "--ff-only"]);
}

export function gitCommitPushAfterWrite(paths: Paths, message: string): GitSyncResult {
  if (!paths.gitSync) return { ok: true, skipped: true, message: "gitSync disabled" };
  if (!isGitRepo(paths)) {
    return { ok: false, message: `vault is not a git repository: ${paths.vaultRoot}` };
  }

  const dreamingRel = relative(paths.vaultRoot, paths.dreamingRoot) || "dreaming";

  const add = runGit(paths, ["add", "--", dreamingRel]);
  if (!add.ok) return add;

  const commit = runGit(paths, ["commit", "-m", message]);
  if (!commit.ok) {
    const out = commit.output ?? "";
    // git commit exits non-zero when nothing changed. This is OK.
    if (/nothing to commit|no changes added|working tree clean/i.test(out)) {
      return { ok: true, skipped: true, message: "nothing to commit", output: out };
    }
    return commit;
  }

  return runGit(paths, ["push"]);
}
