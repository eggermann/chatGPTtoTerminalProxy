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
- optional kann der Watcher auch `prompt-concator` mitstarten

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

Ohne Namen:

```bash
cd /Users/eggermann/Desktop/speedProjects/modal-hacka
/path/to/chatGPTtoTerminalProxy/parasit.sh fresh
```

Direkt mit Zielpfad:

```bash
/path/to/chatGPTtoTerminalProxy/parasit.sh fresh /Users/eggermann/Desktop/speedProjects/modal-hacka
/path/to/chatGPTtoTerminalProxy/parasit.sh fresh /Users/eggermann/Desktop/speedProjects/modal-hacka/get_started.py
```

Dann gilt:

- Projektpfad ist der aktuelle Ordner
- ein vorhandener Ordnerpfad wird direkt als Projektpfad verwendet
- ein vorhandener Dateipfad wird auf seinen Ordner aufgelöst
- `.codex-inbox/` liegt in diesem Ordner
- als Session-Name wird standardmäßig `modal-hacka` verwendet

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
