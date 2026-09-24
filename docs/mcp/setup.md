# dataCycle-MCP-Server in Claude Code einrichten

Anleitung, um die MCP-Server der lokalen dataCycle-Instanz in Claude Code verfügbar zu machen — den
instanzweiten Server plus die fünf Test-Endpoints, darunter einen **typübergreifenden**, mit dem
Abfragen wie „alle Inhalte mit Kategorie X, unabhängig vom Inhaltstyp" funktionieren.

Am Code ist dafür nichts zu tun — MCP ist in dieser Engine implementiert. Zu tun sind zwei Dinge:
die Mounts in der Instanz einschalten (siehe „Die Flags" gleich unten) und den Client
konfigurieren (Schritte 1–5).

> **Diese Datei ist die Quelle für Server-Namen, UUIDs und Client-Config.** Sollwerte (Trefferzahlen)
> stehen ausschließlich in [`testabfragen.md`](testabfragen.md), damit sie nicht an zwei Stellen
> auseinanderlaufen. Warum ein Endpoint welchen Scope hat:
> [`testendpoints-pflegen.md`](testendpoints-pflegen.md).

## Engine-Doku, aber instanzabhängige Werte

Die Anleitung liegt in `data-cycle-core`, weil die MCP-Implementierung hier liegt. Vier Dinge kommen
dagegen aus dem **Instanz-Repo**, das die Engine einbindet — gemessen und geschrieben wurde alles
gegen `data-cycle-vcloud-dev`:

| Was | Wo es herkommt |
|---|---|
| Docker-Setup, Port, `.env` | Instanz-Repo bzw. `datacycle-docker` |
| Schreib-Flag `write_enabled` (Schritt 5) | `config/configurations/development/features.yml` **im Instanz-Repo** — die Engine hat hier `false` |
| Alle Trefferzahlen in [`testabfragen.md`](testabfragen.md) | Datenstand der jeweiligen Instanz |
| Die fünf Test-Endpoints selbst | `db/seeds.rb` **im Instanz-Repo** — die Engine seedet keine Endpoints |

Die **Endpoint-UUIDs** unten sind die der `data-cycle-vcloud-dev`-Seeds. Sie sind eine Konvention
dieser Anleitung, keine Zusage der Engine: wer die Endpoints auf einer anderen Instanz anlegt, trägt
dieselben UUIDs ein und bekommt damit dieselben URLs. Schritte 1–5 gelten dann unverändert, nur die
Sollwerte in Stufe 1 sind die der eigenen DB.

## Voraussetzungen

- Die lokale Instanz läuft (`docker compose up -d`), erreichbar unter
  `http://localhost:$PUBLIC_APPLICATION_PORT` — **Default 3003** (gesetzt im Compose-Setup der
  Instanz, `datacycle-docker`). Wer den Port in `.env` geändert hat, ersetzt ihn unten überall.
  `3036` ist der Vite-Dev-Server, nicht Rails.
- Claude Code (VSCode-Extension oder CLI).
- Beide Mounts sind in der Instanz eingeschaltet — die Engine liefert sie **ausgeschaltet** aus,
  siehe den nächsten Abschnitt.

## Die Flags

MCP ist **ein** Feature (`:mcp:` in `config/configurations/features.yml`), das beide Mounts und die
Geo-Kaskade zusammenfasst. Die Engine liefert es ausgeschaltet aus; eingeschaltet wird es im
**Instanz-Repo**, dessen Konfiguration vor der Engine geladen wird und den `deep_merge` gewinnt —
es genügt also, die Schalter zu setzen, die vom Standard abweichen:

```yaml
:mcp:
  :enabled: true
  :mounts:
    :global:
      :enabled: true
    :endpoint:
      :enabled: true
```

| Flag | Was es freischaltet |
|---|---|
| `:mcp: :enabled:` | die MCP-Schicht überhaupt — ohne sie entsteht keiner der beiden Mounts |
| `:mounts: :global: :enabled:` | den instanzweiten Mount `POST /api/mcp` |
| `:mounts: :endpoint: :enabled:` | den endpoint-gescopten Mount `POST /api/v4/endpoints/:id/mcp` |
| `:write_enabled:` (je Mount) | die schreibenden Tools — eigener Schalter, siehe Schritt 5 |
| `:geo: :enabled:` | die Geo-Kaskade hinter `place`/`resolve_place` — bereits an, siehe unten |

Die Geo-Kaskade (`:geo:`) hängt im selben Block und ist als einzige davon bereits eingeschaltet:
`:resolution_trees:` nennt „Administrative Einheiten", den Baum, den dataCycle selbst aus der
Geometrie der Inhalte berechnet. Eine Instanz, die diesen Baum nicht befüllt, zahlt dafür nichts —
es wird kein Label gefunden, und jeder Ortsname antwortet `resolved: false`, genau wie bei
ausgeschaltetem Schalter. Anders als `write_enabled` gibt die Kaskade auch nichts Schreibendes frei,
sondern entscheidet nur, wie gut ein Ortsname auflöst. Weitere Bäume (Tourismusregionen,
Marketinggruppen) sind instanzspezifisch, ebenso `:geo_region_trees:` und
`:postal_code_patterns:`; ohne einen Eintrag in `:resolution_trees:` bleibt der `place`-Filter
wirkungslos — `resolve_place` sagt das dann, und `search_contents` warnt im Envelope.

Drei Dinge, die beim Einschalten sonst überraschen:

- **Ein ausgeschalteter Mount hat gar keine Route.** Der Client bekommt 404, nicht 403 — das ist
  Absicht: eine Route, die sich meldet und dann nichts kann, ist die schlechtere Auskunft.
- **Die erlaubten Hostnamen stehen in `config.hosts`, nicht in der MCP-Konfiguration.** Der Transport
  hat einen DNS-Rebinding-Schutz und bekommt dafür `Rails.application.config.hosts` — dieselbe Liste,
  gegen die `ActionDispatch::HostAuthorization` den `Host`-Header schon vor dem Controller prüft. Die
  Instanz-Templates setzen sie in `config/environments/production.rb` auf `APP_HOST` (plus
  `dockerhost`/`web`/`localhost`), es ist also normalerweise nichts zu tun. Antwortet der Mount mit
  `403 Invalid Host header`, fehlt der Hostname dort — und dann fehlt er der ganzen App, nicht nur
  dem MCP-Mount. Regexp- und `IPAddr`-Einträge kann der Transport nicht auswerten, er vergleicht nur
  die String-Einträge der Liste.
- **`write_enabled` ist absichtlich ein zweiter Schalter**, damit ein Upgrade einer bestehenden
  Installation keine Schreib-Tools unterschieben kann.

## Schritt 1 — eigenen API-Token erzeugen

Der MCP-Transport authentifiziert sich mit demselben Bearer-Token wie die REST-API
(`users.access_token`), und die Tools laufen durch denselben CanCan-Gate wie die REST-Routen. **Jeder
braucht seinen eigenen Token** — niemals einen fremden weiterverwenden, sonst laufen die Abfragen mit
fremden Rechten.

1. In der dataCycle-UI einloggen → eigenes Benutzerprofil bearbeiten.
2. Checkbox **„API Token"** aktivieren → speichern.
3. Der Token erscheint als Schlüssel-Chip neben dem Label und lässt sich per Klick kopieren.

Fehlt die Checkbox, fehlt das Recht `generate_access_token` — dann bei einem Admin anfragen. Notfalls
per Konsole:

```bash
docker compose exec web bin/rails runner \
  'u = DataCycleCore::User.find_by(email: "DEINE@MAIL"); u.update_access_token!; puts u.access_token'
```

Token als Env-Var ablegen (Shell-Profil), damit er nicht in Configs im Repo landet:

```bash
export DC_API_TOKEN="…"
```

## Schritt 2 — die Endpoints

Ein Endpoint ist ein `StoredFilter` mit `api: true`; jede `/api/v4/endpoints/<uuid>/mcp`-URL ist damit
ein eigener MCP-Server. Die fünf Test-Endpoints stehen mit **fest eingetragener UUID** im
`db/seeds.rb` des Instanz-Repos ([`testendpoints-pflegen.md`](testendpoints-pflegen.md) ist das
Rezept dafür) und kommen per `bin/rails db:seed`, nicht aus dem Dump. Auf einer Instanz, die sie
nicht seedet, existieren sie nicht — dann liefert die Abfrage unten eine leere Liste:

```bash
curl -s -X POST "http://localhost:3003/api/mcp" \
  -H "Authorization: Bearer $DC_API_TOKEN" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"list_endpoints","arguments":{}}}'
```

| Server-Name in der Config | Endpoint / UUID | Scope |
|---|---|---|
| `datacycle` | *kein Endpoint*, `/api/mcp` | instanzweit, unkuratiert; einziger Server mit `list_endpoints`, `get_schema`, `browse_concept_schemes`, `list_concepts`, `select_things`, `universal_lookup`, `recent_queries` |
| `datacycle-alle-inhalte` | MCP Test - Alle Inhalte<br>`f2c81a90-3d47-4e6b-9c15-8ad70e4b6c31` | **typübergreifend**, kein Template-Filter, keine Pool-Beschränkung, 83 unkuratierte Bäume |
| `datacycle-tourismus` | MCP Test - Tourismus<br>`ae27409b-61db-48d6-bb71-0a74d804440a` | POIs, Unterkünfte, Skigebiete, Redaktionsartikel (12 Templates), 8 kuratierte Bäume |
| `datacycle-events` | MCP Test - Events<br>`745352f5-35d0-4a9f-9fc2-b52c237f12a0` | `Event`/`EventSeries`, 4 kuratierte Bäume |
| `datacycle-touren` | MCP Test - Touren<br>`1c8d4f27-6a3b-4e59-9f0d-2b7e5a1c93f4` | `Trail` — **einziger** Endpoint mit Touren, 4 kuratierte Bäume |
| `datacycle-kulinarisches-erbe` | KulinarischesErbe<br>`c9de1115-1459-4c91-ba09-cffb53d68bb4` | `Recipe`/`CulinaryHeritage`/`FoodEstablishment`, **unkuratierte** Facetten (14 abgeleitete Bäume) |

Trefferzahlen zu jedem Server: [`testabfragen.md`](testabfragen.md), Stufe 1.

> **Zwei UUIDs, die nach dem Richtigen klingen und es nicht sind.** Beide sind fremde
> Object-Browser-Filter, beide antworten plausibel:
>
> - `88bdeca1-4b1a-493c-bf75-1c65a771a597` („Alle aktuellen Inhalte") ist **nicht** der
>   typübergreifende Endpoint: `api = false`, keine kuratierten Bäume, eingeschränkt auf den
>   Inhaltspool „Aktuell" — das macht Tausende Inhalte unsichtbar (`Recipe` 0 statt 17), **ohne dass
>   das an der Antwort erkennbar ist**. Er bleibt unverändert, weil ihn der Object Browser verwendet
>   (`user_filters.yml`); für MCP ist `f2c81a90…` der richtige.
> - `fd9ec2f6-5d42-44ee-a4a7-c6db13cc2824` („Alle Personen & Organisationen") ist **kein**
>   Tourismus-Endpoint: er führt `Organization`, `LodgingBusiness`, `MountainArea`, `Person`, aber
>   **kein** `TouristAttraction` und **kein** `Place`. Wer ihn als `datacycle-tourismus` registriert,
>   hat keinen einzigen POI im Scope.
>
> Beide standen in früheren Fassungen dieser Anleitung. Deshalb nach dem Einrichten Stufe 1 aus
> [`testabfragen.md`](testabfragen.md) durchlaufen — die Zahlen decken eine Verwechslung sofort auf.

## Schritt 3 — Server in Claude Code registrieren

Config-Datei `~/.claude.json`, im Block des jeweiligen Projekt-Pfads. Claude Code beim Bearbeiten
schließen, sonst überschreibt es die Änderung wieder.

```jsonc
"/pfad/zum/instanz-repo": {   // z.B. /Users/DEINNAME/Documents/data-cycle-vcloud-dev
  "mcpServers": {
    // instanzweit: Schema, Concepts, Endpoint-Discovery — unkuratiert, s. Schritt 2
    "datacycle": {
      "type": "http",
      "url": "http://localhost:3003/api/mcp",
      "headers": { "Authorization": "Bearer DEIN_TOKEN" }
    },
    // typübergreifende Suche — der wichtige für "unabhängig vom Inhaltstyp"
    "datacycle-alle-inhalte": {
      "type": "http",
      "url": "http://localhost:3003/api/v4/endpoints/f2c81a90-3d47-4e6b-9c15-8ad70e4b6c31/mcp",
      "headers": { "Authorization": "Bearer DEIN_TOKEN" }
    },
    // POIs & Unterkünfte — NICHT fd9ec2f6… nehmen, das ist der Organisationen-Filter
    "datacycle-tourismus": {
      "type": "http",
      "url": "http://localhost:3003/api/v4/endpoints/ae27409b-61db-48d6-bb71-0a74d804440a/mcp",
      "headers": { "Authorization": "Bearer DEIN_TOKEN" }
    },
    "datacycle-events": {
      "type": "http",
      "url": "http://localhost:3003/api/v4/endpoints/745352f5-35d0-4a9f-9fc2-b52c237f12a0/mcp",
      "headers": { "Authorization": "Bearer DEIN_TOKEN" }
    },
    "datacycle-touren": {
      "type": "http",
      "url": "http://localhost:3003/api/v4/endpoints/1c8d4f27-6a3b-4e59-9f0d-2b7e5a1c93f4/mcp",
      "headers": { "Authorization": "Bearer DEIN_TOKEN" }
    },
    "datacycle-kulinarisches-erbe": {
      "type": "http",
      "url": "http://localhost:3003/api/v4/endpoints/c9de1115-1459-4c91-ba09-cffb53d68bb4/mcp",
      "headers": { "Authorization": "Bearer DEIN_TOKEN" }
    }
  }
}
```

JSONC-Kommentare vor dem Speichern entfernen — die Datei ist striktes JSON. Wer die CLI installiert
hat, kann statt Handarbeit `claude mcp add` nehmen (`claude mcp add --help` für die aktuelle
Flag-Syntax des HTTP-Transports und der Header).

Die Server-Namen sind nicht kosmetisch: Claude adressiert die Tools als
`mcp__datacycle-touren__search_contents`. Wer anders benennt, kann die Prompts aus
[`testabfragen.md`](testabfragen.md) nicht unverändert verwenden.

Danach VSCode-Fenster neu laden bzw. `/mcp reconnect all`. `/mcp` muss alle sechs Server als
*connected* zeigen.

## Schritt 4 — Rauchtest

```bash
curl -s -X POST "http://localhost:3003/api/v4/endpoints/f2c81a90-3d47-4e6b-9c15-8ad70e4b6c31/mcp" \
  -H "Authorization: Bearer $DC_API_TOKEN" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"search_contents","arguments":{"limit":50}}}'
```

Jedes Tool antwortet in derselben Hülle: `{"ok": true, "data": …}`, im Fehlerfall `{"ok": false,
"errors": [{"source", "title", "detail"}]}` — dieselbe Fehlerform, die auch die REST-API liefert. Das
eigentliche Ergebnis steht also unter `data`, und `structuredContent` und der Textblock tragen beide
dieselbe Hülle. Steht zusätzlich ein `warnings` daneben, nennt es, worauf die Zahl im selben
Ergebnis beruht — etwa übergebene Concept-IDs, die gar nichts gefiltert haben. Ohne Warnungen fehlt
der Schlüssel, ein leeres Array gibt es nicht.

In `data.items` müssen **mehrere verschiedene** `template_name` auftauchen (z. B. `CulinaryHeritage`,
`ProtectedArea`, `Person`). Kommt nur einer, hängt die URL am falschen Endpoint.

Damit ist die Verbindung bewiesen, nicht der Datenstand. Ob die DB dem Team-Stand entspricht, klärt
Stufe 1 in [`testabfragen.md`](testabfragen.md) — inklusive Summenproben, die anschlagen, sobald
Seed, Scope oder Gem-Stand abweichen. **Weichen Zahlen ab, ist fast immer nur `db:seed` fällig, kein
Dump-Restore:**

```bash
docker compose exec web bin/rails db:seed
```

## Schritt 5 — Schreiben freischalten (nur lokal)

Zusätzlich zu den lesenden Tools gibt es drei **schreibende**: `list_writable_attributes`,
`create_content`, `update_content`. Sie hängen an einem eigenen Flag, das **in der Engine auf
`false`** steht:

```yaml
:mcp:
  :mounts:
    :global:
      :write_enabled: true
    :endpoint:
      :write_enabled: true
```

Freigeschaltet wird es **nicht hier, sondern im Instanz-Repo.** In `data-cycle-vcloud-dev` steht der
Block in `config/configurations/development/features.yml` und gilt damit **nur für
`Rails.env development`** — Staging/Produktion bleiben rein lesend, bis derselbe Block bewusst in
`config/configurations/features.yml` wandert (Achtung: gilt dann für jede Umgebung). Die
Konfiguration der Instanz wird vor der Engine-Konfiguration geladen und gewinnt den `deep_merge`.
Warum das Flag im Core auf `false` steht: ein Upgrade darf einer bestehenden Installation keine
Schreib-Tools unterschieben.

Ist das Flag aus, fehlen die Tools ganz in
`tools/list` (kein „gesperrt", sondern „gibt's nicht"). Nach dem Umstellen den `web`-Container neu
starten, damit die YAML neu geladen wird, und danach Claude Code neu starten — der Client cacht die
Tool-Liste:

```bash
docker compose restart web
```

Rauchtest und die Prüfschritte danach: [`testabfragen.md`](testabfragen.md), Stufe 5. Er **legt
wirklich einen Datensatz an**. Der eine Punkt, der jede/n einmal erwischt: Attributnamen kommen aus
`list_writable_attributes`, **nicht** aus `get_schema` — ein API-Name (`odta:length`) als Key legt
den Datensatz an und verwirft den Wert stillschweigend. Ebenso verbindlich ist die `unit` von dort:
`length` in Metern, `duration` in Minuten (das trägt gar kein `unit`-Feld, die Einheit steht nur im
Label). Die Antwort nennt in `applied_attributes`/`ignored_attributes`, was wirklich ankam.

## Fallstricke beim Einrichten

- **401 bei jedem Tool** → Token fehlt/ungültig, **oder** der Endpoint hat `api: false`. Alle Fälle
  antworten absichtlich identisch 401; abgesichert in
  [`test/integration/api/v4/mcp/mcp_authorization_test.rb`](../../test/integration/api/v4/mcp/mcp_authorization_test.rb).
  Erst den Token gegen `/api/mcp` prüfen,
  dann die UUID.
- **Server verbindet nicht nach `docker compose up -d web`** → Rails hängt an nginx auf dem
  Public-Port; der `web`-Container allein reicht nicht. Ohne Netz läuft der Entrypoint (`gem install`,
  `pnpm`) in eine Restart-Schleife.
- **`Translation missing: all.mcp.tools.*.description`** in den Tool-Listen → nur fehlende i18n-Keys
  in der Endpoint-Variante, kein Fehler. Die Parameter-Beschreibungen sind übersetzt.
- **Falscher Port** → `3003` ist Rails, `3036` der Vite-Dev-Server. Am Vite-Port antwortet kein MCP.
- **Endpoint-UUIDs nicht hart in geteilte Configs schreiben,** die auch auf Instanzen mit anderem
  Seed-Stand laufen. Das gilt auch für die fünf Test-Endpoints: sie sind nur dort vorhanden, wo das
  Instanz-Repo sie seedet.

## Optional: `.mcp.json` im Repo statt pro Person

Claude Code liest auch eine projekt-scoped `.mcp.json` im Repo-Root, was die Server für alle
automatisch verfügbar macht. Dann aber **ohne Token im Klartext** — nur mit Env-Var-Referenz
(`"Authorization": "Bearer ${DC_API_TOKEN}"`), sodass jeder seinen eigenen Token exportiert. Das haben
wir noch nicht ausprobiert, und es liegt derzeit **keine** `.mcp.json` im Repo; wer sie einführt,
verifiziert vorher mit `/mcp`, dass die Expansion greift, und ergänzt hier das Ergebnis.
