# parasit.sh Manual

`parasit.sh` ist der Einstiegspunkt für Session- und Watcher-Steuerung.

## Kurzform

- `./parasit.sh` startet nur den Watcher
- `./parasit.sh fresh <name>` erstellt eine neue Session
- `./parasit.sh open <branch>` öffnet eine bestehende Session
- eine Session ist ein Git-Branch mit Prefix `codex/session/`
- `.codex-inbox` ist Datenbereich
- `bin/` ist Tool-Bereich

## Was beim Fresh passiert

`./parasit.sh fresh <name>` macht:

1. alte Inbox-Dateien nach `.codex-inbox/.archive/<name>/` verschieben
2. neuen Branch `codex/session/<name>` anlegen
3. auf den neuen Branch wechseln
4. `chat.txt` aus `bin/chat-template.md` befüllen
5. `conversation-base.md` aus `bin/conversation-base.md` kopieren
6. `memory.md` für den neuen Branch schreiben
7. `session.json` und andere Laufzeitdateien neu anlegen
8. `./bin/watch-chat-first.sh` automatisch starten

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
- `bin/conversation-base.md` - Template für `conversation-base.md`
- `.codex-inbox/conversation-base.md` - frische Kopie pro Session
- `.codex-inbox/.archive/` - Archiv alter Sessions

## Regeln

- Session-Namen werden zu Git-Branch-Namen normalisiert
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

