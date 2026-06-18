# parasit.sh Manual

`parasit.sh` ist der Einstiegspunkt für Session- und Watcher-Steuerung.

## Kurzform

- `./parasit.sh` startet nur den Watcher
- `./parasit.sh fresh <name>` erstellt eine neue Session
- `./parasit.sh fresh` nimmt den aktuellen Ordnernamen als Session-Namen
- `./parasit.sh open <branch>` öffnet eine bestehende Session
- eine Session ist ein Git-Branch im inneren `.codex-inbox`-Repo mit Prefix `codex/session/`
- `autocommit` steuert den Hinweistext und den Auto-Commit bei erfolgreichem Output
- `promptConcator.enabled` startet optional `npx prompt-concator --watch`
- `.codex-inbox` ist inneres Git-Repo und Datenbereich
- `bin/` ist Tool-Bereich

## Was beim Fresh passiert

`./parasit.sh fresh <name>` macht:

1. alte Inbox-Dateien nach `.codex-inbox/.archive/<name>/` verschieben
2. im inneren `.codex-inbox`-Repo neuen Branch `codex/session/<name>` anlegen
3. auf den neuen Branch wechseln
4. `chat.txt` aus `bin/chat-template.md` befüllen
5. `memory.md` für den neuen Branch schreiben
6. `session.json` und andere Laufzeitdateien neu anlegen
7. `./bin/watch-chat-first.sh` automatisch starten

Wenn kein Name übergeben wird, wird der aktuelle Ordnername verwendet. In

```bash
cd /Users/eggermann/Desktop/speedProjects/modal-hacka
/path/to/chatGPTtoTerminalProxy/parasit.sh fresh
```

entsteht also standardmäßig die Session `codex/session/modal-hacka`, und
`.codex-inbox/` wird unter `modal-hacka/` aufgelöst.

Alternativ kann `fresh` direkt einen vorhandenen Zielpfad annehmen:

```bash
/path/to/chatGPTtoTerminalProxy/parasit.sh fresh /Users/eggermann/Desktop/speedProjects/modal-hacka
/path/to/chatGPTtoTerminalProxy/parasit.sh fresh /Users/eggermann/Desktop/speedProjects/modal-hacka/get_started.py
```

Ein Ordnerpfad wird direkt als Projektordner verwendet. Ein Dateipfad wird auf
seinen Elternordner aufgelöst.

## Befehle

```bash
./parasit.sh
./parasit.sh fresh hello-world
./parasit.sh open codex/session/hello-world
./parasit.sh delete codex/session/hello-world
./parasit.sh list
./parasit.sh status
```

## Workflow

1. Watcher starten
2. `chat.txt` als Prompt-Fläche nutzen
3. `commands.txt` nur für finale Shell-Kommandos nutzen
4. `last-output.md` nach Ausführung lesen
5. bei Bedarf nächste Session als neuen Git-Branch anlegen

## Dateien

- `bin/chatgpt-parasit.sh` - Session-CLI
- `parasit.sh` - Root-Wrapper
- `bin/chat-template.md` - Starttext für `chat.txt`
- `.codex-inbox/.archive/` - Archiv alter Sessions

## Regeln

- Session-Namen werden zu Git-Branch-Namen im inneren Repo normalisiert
- `fresh` startet immer mit frischer Inbox
- alte Session-Dateien werden archiviert, nicht vermischt
- `chat.txt` und `commands.txt` bleiben getrennt

## Beispiel

Neue Session:

```bash
./parasit.sh fresh hello-world
```

Dann:

- `chat.txt` prüfen
- Watcher laufen lassen
- in ChatGPT den nächsten Schritt ausführen
