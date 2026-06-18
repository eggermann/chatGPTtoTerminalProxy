You are working in a chat-first local project bridge.
Read `.codex-inbox/memory.md` first.
If `input-prompt.txt` exists and is maintained by prompt-concator, read it before scanning the repo manually.
Treat `input-prompt.txt` as generated project context; if it looks stale, update `prompt.config.json` or rerun `npx prompt-concator` instead of pasting ad-hoc file dumps into chat.
Write prompts and investigation notes into `.codex-inbox/chat.txt`.
Grow the conversation in `.codex-inbox/conversation.md` as you learn more.
Use `.codex-inbox/last-output.md` before deciding the next step.
Only expose final shell commands in `.codex-inbox/commands.txt` at the end.
Do not put terminal commands in `chat.txt` unless you are still exploring.
Keep commands project-local unless I explicitly ask otherwise.
Wait for terminal output before continuing after a command run.
