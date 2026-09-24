# MCP (Model Context Protocol) — Doku-Übersicht

Die MCP-Server einer dataCycle-Instanz nutzen: Einrichtung, Prüfkatalog, Pflege der Test-Endpoints.

## Anleitungen

| Datei | Wofür |
|---|---|
| [`setup.md`](setup.md) | **Einstieg.** Die Flags, Token, Endpoint-UUIDs, `~/.claude.json`, Rauchtest, Schreiben freischalten. |
| [`claude-desktop/`](claude-desktop/README.md) | Dieselben Server in **Claude Desktop** — eigener Ordner, weil Desktop keine HTTP-Server lädt und die stdio-Brücke [`claude-desktop/mcp-http-bridge.py`](claude-desktop/mcp-http-bridge.py) braucht: [`setup.md`](claude-desktop/setup.md) — Config, Startreihenfolge, Logs, Fallstricke. Token und UUIDs kommen aus `setup.md`. |
| [`testabfragen.md`](testabfragen.md) | Prüfkatalog für alle sechs Server — jede Abfrage mit **Sollwert** (Smoke-Test, Tool-Inventar, fachliche Abfragen, Fallenabfragen, Schreibtest) und als Copy-Paste-Prompt. |
| [`testendpoints-pflegen.md`](testendpoints-pflegen.md) | Test-Endpoints anlegen/ändern — ausschließlich über das `db/seeds.rb` des Instanz-Repos, inkl. Merge-Fallstrick. |

## Wo was steht — und wo bewusst nicht

Die Anleitungen lagen zeitweise in drei Fassungen im Instanz-Repo und sind inhaltlich
auseinandergelaufen (Trefferzahlen, Tool-Listen, empfohlene Endpoint-UUIDs — teils mit falschem
Ergebnis). Damit das nicht wieder passiert, hat jede Information **genau einen** Ort:

- **Server-Namen, Endpoint-UUIDs, Client-Config, die Flags** → nur [`setup.md`](setup.md).
- **Trefferzahlen und Sollwerte** → nur [`testabfragen.md`](testabfragen.md), jeweils mit Messdatum
  und Instanz. In den anderen Dateien stehen keine Zahlen.
- **Scope-Entscheidungen** (welches Template, welcher Baum, welches Bündel — und warum) → als
  Kommentar am jeweiligen Eintrag im `db/seeds.rb` des Instanz-Repos; das Vorgehen in
  [`testendpoints-pflegen.md`](testendpoints-pflegen.md).
- **Architektur und Begründungen** (Mounts, Auth-Parität, Tool-Framework, i18n) → als Doc-Blöcke am
  Code selbst: `DataCycleCore::Mcp`, `McpTransportConcern`, `Mcp::Servers::Base`,
  `Mcp::Tools::Base`. Es gibt bewusst kein Architekturdokument daneben, das damit auseinanderläuft.

## Engine-Doku, instanzabhängige Werte

Die Implementierung gehört der Engine, die Test-Endpoints (`db/seeds.rb`) und die **Zahlen** dagegen
der jeweiligen Instanz; gemessen wurde gegen `data-cycle-vcloud-dev`. Ebenfalls instanzseitig:
Docker-Setup/Port und die Flags (in der Engine alle `false`). Details in
[`setup.md`](setup.md), Abschnitt „Engine-Doku, aber instanzabhängige Werte".
