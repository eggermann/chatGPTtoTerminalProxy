# parasit.sh

`parasit.sh` ist der Session-Controller für dieses Projekt. Die ausführliche Version ist hier:

- [`docs/parasit-manual.de.md`](docs/parasit-manual.de.md)

## Wofür

- neue Session anlegen
- Session wechseln
- Session löschen
- Session als Git-Branch verwalten
- - `chat.txt` aus `bin/chat-template.md` befüllen
- alte Inbox pro Session archivieren
- `fresh` startet automatisch `./bin/watch-chat-first.sh`

## Prinzip

- eine Session = ein Git-Branch
- Prefix: `codex/session/`
- `.codex-inbox` bleibt Datenbereich
- `bin/` enthält die ausführbaren Skripte

## Start

```bash
./parasit.sh fresh mein-projekt
```

Das macht:

- neuen Branch anlegen
- auf den Branch wechseln
- `session.json` schreiben
- `memory.md` auf den neuen Branch aktualisieren

## Befehle

```bash
./parasit.sh fresh <name>
./parasit.sh open <branch>
./parasit.sh delete <branch>
./parasit.sh list
./parasit.sh status
```

## Beispiele

Neue Session:

```bash
./parasit.sh fresh hello-world
```

Vorhandene Session öffnen:

```bash
./parasit.sh open codex/session/hello-world
```

Status prüfen:

```bash
./parasit.sh status
```

## Hinweis

- `fresh` ist der Standardstart für einen neuen Session-Zweig im inneren Repo
