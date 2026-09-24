# dataCycle-MCP-Server in Claude Desktop einrichten

Schwesterdatei zu [`../setup.md`](../setup.md): dieselben Server, anderer Client. Claude Desktop kann die
HTTP-Konfiguration von Claude Code **nicht** übernehmen und braucht eine stdio-Brücke.

> **Was hier nicht steht, weil es genau einen Ort hat:** der eigene API-Token
> ([`../setup.md`](../setup.md), Schritt 1), die Endpoint-UUIDs und Server-Namen
> ([`../setup.md`](../setup.md), Schritt 2) und alle Trefferzahlen samt Tool-Anzahl
> ([`../testabfragen.md`](../testabfragen.md)). Diese Datei ergänzt nur den Client.

Warum überhaupt eine Brücke und nicht der Weg von Claude Code, steht im nächsten Abschnitt.

## Warum Desktop nicht so geht wie Claude Code

Claude Code registriert MCP-Server als HTTP-Endpoint (`"type": "http"` mit `url` und `headers`).
Desktop kennt dieses Format nicht und **verwirft solche Einträge stillschweigend** — sichtbar nur im
Log als `Skipped invalid MCP server config entries`. In der App fehlen die Server dann komplett, ohne
Fehlermeldung.

Zwei naheliegende Auswege funktionieren bei dieser Instanz nicht:

| Ausweg | Warum nicht |
|---|---|
| Desktops „Add custom connector" mit OAuth | `DataCycleCore::ApiTokenStrategy` akzeptiert nur `users.access_token` oder ein dekodierbares JWT. Doorkeeper-Tokens sind opak (`UniqueToken`) und werden mit 401 abgelehnt. Zusätzlich fehlen `/.well-known/oauth-protected-resource` und Dynamic Client Registration. Das wäre Gem-Arbeit, keine Konfiguration. |
| `mcp-remote` als stdio-Proxy | Braucht Node/npx. Auf einem Rechner ohne Node keine Option. |

Bleibt eine eigene Brücke: ein stdio-Prozess, der jede JSON-RPC-Nachricht per HTTP POST an den echten
Server weiterreicht — inklusive `Authorization`-Header, den die Connector-UI nicht setzen kann.

## Schritt 1 — Brücke bereitstellen

Das Skript liegt neben dieser Anleitung: [`mcp-http-bridge.py`](mcp-http-bridge.py). Nur
Standardbibliothek, läuft mit dem System-Python (3.9) ohne Installation. Zwei Varianten:

- **Direkt aus dem Repo referenzieren** — nichts zu kopieren, Updates kommen mit dem Gem. Pfad in der
  Config ist dann `<repo>/vendor/gems/data-cycle-core/docs/mcp/claude-desktop/mcp-http-bridge.py`.
- **Nach `~/.claude/bin/` kopieren** — überlebt einen Repo-Wechsel, muss aber bei Änderungen am
  Skript von Hand nachgezogen werden.

`chmod +x` ist nicht nötig, das Skript wird über `python3` aufgerufen.

## Schritt 2 — Config schreiben

| System | Datei |
|---|---|
| macOS | `~/Library/Application Support/Claude/claude_desktop_config.json` |
| Windows | `%APPDATA%\Claude\claude_desktop_config.json` |

Ein Eintrag je Server. Beispiel für einen Endpoint-Server — `<UUID>` aus [`../setup.md`](../setup.md)
Schritt 2, `<TOKEN>` aus Schritt 1:

```json
{
  "mcpServers": {
    "datacycle-tourismus": {
      "command": "/usr/bin/python3",
      "args": ["/Users/DEINNAME/.claude/bin/mcp-http-bridge.py"],
      "env": {
        "MCP_URL": "http://localhost:3003/api/v4/endpoints/<UUID>/mcp",
        "MCP_TOKEN": "<TOKEN>"
      }
    }
  }
}
```

Der instanzweite Server unterscheidet sich nur in der URL (`/api/mcp` statt
`/api/v4/endpoints/<UUID>/mcp`). Die Server-Namen sollten mit denen in Claude Code übereinstimmen —
sonst greifen die Copy-Paste-Prompts aus [`../testabfragen.md`](../testabfragen.md) nicht, die den Server
im Text festlegen.

Steuerung über Umgebungsvariablen:

| Variable | Default | Wofür |
|---|---|---|
| `MCP_URL` | — | Pflicht. Volle URL des MCP-Endpoints. |
| `MCP_TOKEN` | — | Wird als `Authorization: Bearer …` gesendet. Ohne Token nur, wenn der Endpoint offen ist. |
| `MCP_TIMEOUT` | `120` | Sekunden pro HTTP-Request. |
| `MCP_STARTUP_WAIT` | `120` | Sekunden, die das `initialize` auf einen noch startenden Server wartet. Siehe Schritt 3. |
| `MCP_RETRY_WAIT` | `45` | Sekunden, die ein normaler Request einen Serverneustart überbrückt. |

Wiederholt wird nur, was vorübergehend ist: Verbindungsfehler und 502/503/504 (nginx oben, Puma noch
nicht). Ein 401 oder ein Anwendungsfehler wird sofort durchgereicht — den behebt kein Warten.

## Schritt 3 — Startreihenfolge

**Docker muss vor Claude Desktop laufen.** Desktop startet die stdio-Server beim App-Start; ist der
Stack dann noch nicht erreichbar, scheitert `initialize` mit `Connection refused` — und **Desktop
versucht es nie wieder.** Der Server bleibt bis zum nächsten kompletten App-Neustart tot, ohne dass
die UI das kenntlich macht.

`MCP_STARTUP_WAIT` federt genau diesen Fall ab: die Brücke wartet standardmäßig zwei Minuten, statt
beim ersten Fehlschlag aufzugeben. Wer den Stack erst deutlich später hochfährt, muss Desktop
trotzdem neu starten.

Zweite Eigenheit derselben Sorte: **Desktop cacht die Tool-Liste.** Nach jeder Änderung an der Config
oder am Server (neues Tool, geänderte Beschreibung, `docker compose restart web`) die App komplett
beenden und neu starten — ein Fensterschließen reicht nicht.

## Schritt 4 — Rauchtest

Erst die Brücke ohne Desktop prüfen, dann Desktop. So ist eine Fehlerquelle nach der anderen
ausgeschlossen.

```bash
MCP_URL="http://localhost:3003/api/v4/endpoints/<UUID>/mcp" \
MCP_TOKEN="<TOKEN>" \
python3 vendor/gems/data-cycle-core/docs/mcp/claude-desktop/mcp-http-bridge.py <<'EOF'
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1"}}}
{"jsonrpc":"2.0","method":"notifications/initialized"}
{"jsonrpc":"2.0","id":2,"method":"tools/list"}
EOF
```

Erwartet: eine `initialize`-Antwort mit `serverInfo` und danach die Tool-Liste. Auf stderr steht eine
Zeile `[mcp-http-bridge] verbinde mit … (Token: ja)` — steht dort `Token: nein`, greift `MCP_TOKEN`
nicht.

Danach in Desktop: die Prompts aus [`../testabfragen.md`](../testabfragen.md) durchgehen. Dort steht auch
die erwartete Tool-Anzahl je Server; weicht sie ab, zeigt die Config auf die falsche URL.

## Schritt 5 — Prompts und Resources finden

Die Server bieten neben Tools auch MCP-**Prompts** und -**Resources** an. In Claude Desktop stehen
Prompts **hinter dem „+"-Button** neben dem Eingabefeld, pro Server gelistet — sie sind **keine**
Slash-Befehle. Als `/name` getippt löst nichts aus: im Log erscheint dann gar kein `prompts/get`, der
Aufruf erreicht den Server nie.

## Fallstricke

| Symptom | Ursache | Prüfen |
|---|---|---|
| Server fehlt komplett, keine Fehlermeldung | `"type": "http"` in der Desktop-Config | `grep -i "skipped invalid" ~/Library/Logs/Claude/main.log` |
| Alle Server tot, Neustart hilft | Desktop wurde vor Docker gestartet | `mcp-server-<name>.log`: `Connection refused`, danach `error(code=-32000)` |
| Server antwortet 401 | fremder oder abgelaufener Token | Die Brücke meldet `HTTP 401 … (Token pruefen: MCP_TOKEN)` |
| Tools fehlen nach einer Serveränderung | Desktop cacht die Tool-Liste | App komplett beenden und neu starten |
| Tools da, aber Klassifikationsfilter liefern `Invalid request` | ausstehende Migrationen (`collected_concept_contents.hidden`) | `docker compose exec web bundle exec rails db:migrate:status`, dann das Feld `error` im Activity-INSERT in `docker compose logs web` |
| Prompt getippt, nichts passiert | Prompts sind kein Slash-Befehl | Schritt 5 |
| `HTTP 406` bei einem eigenen Client | `Accept: text/event-stream` fehlt | Die Brücke setzt den Header selbst; betrifft nur handgeschriebene Clients |

## Logs

Alles unter `~/Library/Logs/Claude/`:

| Datei | Inhalt |
|---|---|
| `main.log` | App-Start, verworfene Config-Einträge |
| `mcp.log` | alle Server gemeinsam, je Nachricht eine Zeile |
| `mcp-server-<name>.log` | ein Server einzeln — hier steht auch das stderr der Brücke |

Bei „Server fehlt in Desktop" **immer erst hier** suchen, nicht am Server: die Server selbst sind per
`curl` prüfbar und meist in Ordnung.

## Parität zu Claude Code prüfen

Beide Clients müssen auf dieselben URLs mit demselben Token zeigen. Ist das gegeben, sind Tool-,
Prompt- und Resource-Sätze identisch — Desktop kann dann fachlich genau das, was Claude Code kann.
Zum Nachweis dieselbe Nachrichtenfolge zweimal senden: einmal per `curl` gegen die URL (der Weg von
Claude Code) und einmal per Skript aus Schritt 4 (der Weg von Desktop), dann die Namenslisten
vergleichen. Unterschiedliche Zahlen bedeuten fast immer unterschiedliche URLs oder Tokens in den
beiden Configs, nicht unterschiedliche Fähigkeiten der Clients.
