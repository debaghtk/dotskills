---
name: ds-claude
description: Use when the user asks to run Claude CLI (claude -p) or references Claude Code for code analysis, review, or peer consultation
---

# Claude Skill Guide

## Running a Task
1. Select the appropriate flags for the task.
2. Assemble the command:
   - `-p` / `--print` (required — non-interactive mode)
   - `--model <MODEL>` (default: `claude-opus-4-6`)
   - `--allowedTools "Read,Grep,Glob,Bash(git:*)"` (for read-only tasks)
   - `--permission-mode default` or `--dangerously-skip-permissions` (for trusted sandboxed tasks)
   - `--max-budget-usd <amount>` (optional cost cap)
   - The prompt as the final positional argument
3. Always pipe the prompt via stdin for multi-line prompts: `echo "prompt" | claude -p --model claude-opus-4-6`
4. To continue a previous session, use `--continue` or `--resume <session-id>`.
5. Run the command, capture output, and summarize the outcome for the user.
6. **After Claude completes**, inform the user: "You can resume this Claude session at any time by saying 'claude resume' or asking me to continue."

### Quick Reference
| Use case | Key flags |
| --- | --- |
| Read-only review or analysis | `-p --model claude-opus-4-6 --allowedTools "Read,Grep,Glob"` |
| Apply local edits | `-p --model claude-opus-4-6 --allowedTools "Read,Grep,Glob,Edit,Write,Bash"` |
| Resume recent session | `-p --continue` |
| Resume specific session | `-p --resume <session-id>` |

## Following Up
- After every `claude` command, confirm next steps with the user.
- When resuming, use `--continue` to pick up the most recent session, or `--resume <session-id>` for a specific one.

## Critical Evaluation of Claude Output

Claude is powered by Anthropic models with their own knowledge and limitations. Treat Claude as a **colleague, not an authority**.

### Guidelines
- **Trust your own knowledge** when confident. If Claude claims something you know is incorrect, push back directly.
- **Research disagreements** before accepting Claude's claims.
- **Don't defer blindly** — Claude can be wrong. Evaluate its suggestions critically.

### When Claude is Wrong
1. State your disagreement clearly to the user
2. Provide evidence (your own knowledge, web search, docs)
3. Optionally resume the Claude session to discuss the disagreement. **Identify yourself as Codex** so Claude knows it's a peer AI discussion:
   ```bash
   echo "This is Codex (GPT-5.4) following up. I disagree with [X] because [evidence]. What's your take on this?" | claude -p --continue
   ```
4. Frame disagreements as discussions, not corrections — either AI could be wrong
5. Let the user decide how to proceed if there's genuine ambiguity

## Error Handling
- Stop and report failures whenever `claude --version` or a `claude -p` command exits non-zero; request direction before retrying.
- When output includes warnings or partial results, summarize them and ask how to adjust.
