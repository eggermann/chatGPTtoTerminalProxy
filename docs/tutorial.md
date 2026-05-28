# Tutorial

## 1. What to put in ChatGPT first

Start a new ChatGPT chat with this:

```text
You are working in a chat-first local project bridge.
Read `.codex-inbox/memory.md` first.
Use `.codex-inbox/chat.txt` for the current prompt.
Use `.codex-inbox/conversation.md` for growing context.
Use `.codex-inbox/last-output.md` before the next step.
Only put final shell commands into `.codex-inbox/commands.txt`.
Keep commands project-local unless I say otherwise.
Wait for terminal output before continuing.
```

Then write the actual goal in `chat.txt`, for example:

```text
Make a hello world web page first.
Do not jump to npm yet.
```

Keep `memory.md` small:

- project title
- project path
- branch name
- one-line purpose

If you want a fresh session base, copy the template from `bin/conversation-base.md` into `.codex-inbox/conversation-base.md`.

## 2. What to turn on

Open and keep open:

- ChatGPT app
- VS Code or Cursor with this repo open
- Terminal running `./parasit.sh`

Also turn on:

- VS Code autosave after delay
- ChatGPT `Work with Apps`
- VS Code selected in `Work with Apps`

In ChatGPT with `Work with Apps`, keep these files open:

- `.codex-inbox/chat.txt` for the current prompt
- `.codex-inbox/memory.md` for stable facts
- `.codex-inbox/last-output.md` after a command run
- `.codex-inbox/conversation.md` if you want the growing context visible

Start with `chat.txt` and `memory.md`. Open `last-output.md` after the first terminal run.

Important:

- typing alone should not send anything
- the watcher reacts after save, then waits for the file to stay stable
- `activateWatchOnSave.chat` and `activateWatchOnSave.commands` should both stay `true`
- if you want to force a send, let the file save and stop typing

## 3. Create the first hello world project

Do this through the bridge:

- write the goal into `.codex-inbox/chat.txt`
- let ChatGPT create the command in `.codex-inbox/commands.txt`
- approve it in the watcher
- let the watcher run it in the project folder

The first goal can be:

```text
Create a clean hello world project in `~/codex-projects/hello-world`.
Make a plain `index.html`.
No npm yet.
Open the result in the browser.
```

Expected command content:

```bash
mkdir -p ~/codex-projects/hello-world
cd ~/codex-projects/hello-world
cat > index.html <<'EOF'
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Hello World</title>
  </head>
  <body>
    <h1>Hello World</h1>
    <p>Plain HTML. No npm. No build step.</p>
  </body>
</html>
EOF
open index.html
```

But do not run that by hand if you want the bridge flow. Put the goal in ChatGPT or `chat.txt` and let the watcher execute it.

What happens:

- browser opens a plain HTML page
- no watcher magic needed yet
- ChatGPT can stay focused on the file

## 4. What the terminal output means

After a command runs:

- the watcher writes output to the terminal
- the latest result goes to `.codex-inbox/last-output.md`
- longer history goes to `.codex-inbox/conversation.md`

If ChatGPT does not visibly react:

- read `.codex-inbox/last-output.md`
- check the terminal window
- continue only after you know the command result

That is the missing signal path:

- terminal output is the source of truth
- `last-output.md` is the handoff file
- it is replaced only after the command finishes
- `last-output.md` is also the trigger file for the ChatGPT ping
- the header includes `session_id`, `source`, and `command`
- ChatGPT should not guess
- the done ping should say: `Check .codex-inbox/last-output.md now.`

For a manual terminal, wrap the command:

```bash
./bin/capture-output.sh "npm start"
```

## 5. Improve the hello world step

Open a new ChatGPT chat with this goal:

```text
Goal: improve the hello world page.
Use the current project files.
Keep the project small.
After the page works, suggest the next improvement.
```

Expected result:

- new chat starts fresh
- ChatGPT sees the hello world result
- ChatGPT is ready for one improvement at a time

## 6. Move to npm and bundler

When plain HTML is done, create a real project:

```bash
mkdir -p ~/codex-projects/my-app
cd ~/codex-projects/my-app
npm init -y
npm install -D vite typescript
mkdir -p src
cat > index.html <<'EOF'
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>My App</title>
  </head>
  <body>
    <div id="app"></div>
    <script type="module" src="/src/main.ts"></script>
  </body>
</html>
EOF
cat > src/main.ts <<'EOF'
document.querySelector<HTMLDivElement>('#app')!.innerHTML = `
  <main style="font-family: system-ui; padding: 2rem;">
    <h1>Hello from Vite</h1>
    <p>Bundled from <code>src/main.ts</code></p>
  </main>
`
EOF
cat > tsconfig.json <<'EOF'
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "strict": true
  },
  "include": ["src"]
}
EOF
node -e "const fs=require('fs');const pkg=require('./package.json');pkg.scripts={dev:'vite',build:'vite build',preview:'vite preview'};fs.writeFileSync('package.json',JSON.stringify(pkg,null,2)+'\\n')"
npm run dev
```

Why this step:

- `src/` keeps source separate
- Vite gives you a dev server and bundler
- TypeScript is a good default for real projects

## 7. Rule of thumb

- Plain HTML first
- Then npm + `src/` + Vite
- Keep `chat.txt` for prompts
- Keep `commands.txt` only for final shell commands
