# dataCycle-MCP in Claude Desktop

Alles, was **nur** für den Client Claude Desktop gilt. Die Server selbst, ihre Endpoint-UUIDs, der
API-Token und alle Sollwerte gehören nicht hierher — Übersicht in [`../README.md`](../README.md).

| Datei | Wofür |
|---|---|
| [`setup.md`](setup.md) | **Einstieg.** Brücke bereitstellen, `claude_desktop_config.json` schreiben, Startreihenfolge, Rauchtest, Logs, Fallstricke. |
| [`mcp-http-bridge.py`](mcp-http-bridge.py) | Die stdio↔HTTP-Brücke. Nur Standardbibliothek, läuft mit dem System-Python. |

**Kurzfassung, falls die Zeit fehlt:** Desktop lädt keine HTTP-MCP-Server und verwirft solche
Config-Einträge stillschweigend — deshalb die Brücke. Docker muss **vor** Desktop laufen. Nach jeder
Änderung an Config oder Server die App komplett neu starten, sie cacht die Tool-Liste.

> **Pfad hat sich geändert:** Diese Dateien lagen bis 11.08.2026 direkt in `docs/mcp/`
> (`setup-claude-desktop.md`, `mcp-http-bridge.py`). Wer die Brücke in
> `claude_desktop_config.json` über den Repo-Pfad referenziert, muss `claude-desktop/` ergänzen; eine
> nach `~/.claude/bin/` kopierte Brücke ist nicht betroffen.
