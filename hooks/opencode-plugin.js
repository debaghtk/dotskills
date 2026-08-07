// OpenCode plugin adapter for dotskills hooks.
//
// Reuses the exact same bash scripts (and JSON contract) as the Claude Code,
// Codex CLI, and Kimi Code hooks — see hooks/README.md. OpenCode's plugin
// hooks don't speak that contract natively (no stdin JSON, no exit-code
// blocking), so this file translates:
//
//   - tool.execute.before: builds the same {tool_input: {...}} JSON the
//     scripts expect, feeds it via stdin, and treats exit code 2 as "block"
//     by throwing (any other exit code — including a missing `jq`/`bash` or
//     an unreachable /dev/tty — fails open, same as the other adapters).
//   - tool.execute.after: the drift nags never block, so they just run with
//     stderr passed through to the terminal.
//
// Installed by install.sh as a symlink into .opencode/plugins/ (project) or
// ~/.config/opencode/plugins/ (personal) — dropping a file there is enough
// for OpenCode to auto-load it, no config.json entry required.

import { spawnSync } from "node:child_process"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"

const HOOKS_DIR = dirname(fileURLToPath(import.meta.url))

function runBlockingHook(script, payload) {
  const result = spawnSync("bash", [join(HOOKS_DIR, script)], {
    input: JSON.stringify(payload),
    encoding: "utf8",
  })
  if (result.error) return // bash unavailable — fail open
  if (result.status === 2) {
    const reason = (result.stderr || "").trim() || `Blocked by dotskills hook: ${script}`
    throw new Error(reason)
  }
}

function runNagHook(script) {
  spawnSync("bash", [join(HOOKS_DIR, script)], { stdio: ["ignore", "ignore", "inherit"] })
}

export const DotskillsHooks = async () => {
  return {
    "tool.execute.before": async (input, output) => {
      if (input.tool === "bash") {
        runBlockingHook("block-railway.sh", { tool_input: { command: output.args.command } })
      }
      if (input.tool === "write" || input.tool === "edit") {
        runBlockingHook("approve-tests.sh", { tool_input: { file_path: output.args.filePath } })
      }
    },
    "tool.execute.after": async (input) => {
      if (input.tool === "bash") {
        runNagHook("architecture-drift.sh")
        runNagHook("product-drift.sh")
      }
    },
  }
}
