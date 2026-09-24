# MCP-Testabfragen — alle Server und Endpoints

Prüfkatalog für die sechs registrierten MCP-Server. Jede Abfrage hat einen **Sollwert**; weicht er ab,
stimmt Seed, Scope oder Gem-Stand nicht. Alle Werte in diesem Dokument sind am **04.08.2026** gegen
die lokale Instanz gemessen, nicht aus einer älteren Anleitung übernommen.

> **Diese Datei ist die einzige Quelle für Sollwerte.** Server-Namen, UUIDs und Client-Config stehen in
> [`setup.md`](setup.md), die Begründung der Scopes in
> [`testendpoints-pflegen.md`](testendpoints-pflegen.md). Zahlen gehören nicht in diese beiden Dateien
> — sie liefen dort auseinander, wie es bis 04.08.2026 der Fall war.

Zwei Wege, jede Abfrage auszuführen:

- **Als Prompt in Claude Code** — die „Frage"-Spalte in eine Session tippen. Testet den ganzen Weg
  inklusive Tool-Auswahl durch das Modell.
- **Als Roh-Call per curl** — testet nur Server und Query-Layer, ohne Modell. Vorlage:

```bash
dcmcp() {  # dcmcp <server-pfad> <tool> <json-args>
  curl -s -X POST "http://localhost:3003$1" \
    -H "Authorization: Bearer $DC_API_TOKEN" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json, text/event-stream" \
    -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":{\"name\":\"$2\",\"arguments\":$3}}"
}
dcmcp /api/mcp list_endpoints '{}'
dcmcp /api/v4/endpoints/1c8d4f27-6a3b-4e59-9f0d-2b7e5a1c93f4/mcp search_contents '{"limit":1}'
```

## Stufe 1 — Smoke-Test: `search_contents` ohne Filter

Ein Call pro Server, `count` vergleichen. Schlägt hier etwas fehl, sind alle weiteren Stufen sinnlos.

| Server | Pfad | `count` | Bäume | Templates |
|---|---|---|---|---|
| `datacycle` | `/api/mcp` | **260.897** | 83 | 33 |
| `datacycle-alle-inhalte` | `…/endpoints/f2c81a90-…/mcp` | **260.897** | 83 | 33 |
| `datacycle-tourismus` | `…/endpoints/ae27409b-…/mcp` | **19.831** | 8 | 11 |
| `datacycle-events` | `…/endpoints/745352f5-…/mcp` | **6.244** | 4 | 2 |
| `datacycle-touren` | `…/endpoints/1c8d4f27-…/mcp` | **2.510** | 4 | 1 |
| `datacycle-kulinarisches-erbe` | `…/endpoints/c9de1115-…/mcp` | **110** | 14 | 3 |

Bäume = `list_facets` → `schemes[]`, Templates = `list_templates` → `templates[]`.

Zwei Werte in dieser Tabelle sehen nach Fehler aus und sind keiner:

- **Tourismus zeigt 11 Templates, im Seed stehen 12.** `list_templates` gruppiert über die Inhalte im
  Scope (`group(:template_name)`), ein Template ohne Inhalte erscheint also gar nicht.
- **Kulinarisches Erbe hat 14 Bäume, nicht 4.** Der Endpoint hat im Seed **keine**
  `concept_scheme_ids`, `list_facets` fällt damit auf alle abgeleiteten Bäume zurück — inklusive
  Inhaltspools, Lizenzen, Ausgabekanäle. Das ist der einzige kuratierte Endpoint ohne Kuratierung der
  Facetten (offener Punkt, siehe [`testendpoints-pflegen.md`](testendpoints-pflegen.md)).

401 auf allen Tools heißt: Token fehlt/ungültig **oder** der Endpoint hat `api: false` — beide Fälle
antworten absichtlich identisch. Fehlersuche dazu: [`setup.md`](setup.md), „Fallstricke".

## Stufe 2 — Tool-Inventar

`tools/list` je Server. Der globale Server hat **23** Tools, jeder Endpoint-Server **17**. Die Zahlen
setzen sich so zusammen (Registry: [`app/models/data_cycle_core/mcp/servers/`](../../app/models/data_cycle_core/mcp/servers/)):

| Satz | Anzahl | Tools |
|---|---|---|
| `SCOPED_TOOLS` — auf **jedem** Server | 13 | `search_contents`, `get_content`, `suggest`, `suggest_by_title`, `list_facets`, `facet_values`, `resolve_concepts`, `list_attributes`, `resolve_place`, `list_templates`, `statistics`, `timeseries`, `elevation_profile` |
| `WRITE_TOOLS` — auf jedem Server, **wenn** freigeschaltet | 3 | `list_writable_attributes`, `create_content`, `update_content` |
| nur global (`/api/mcp`) | 7 | `select_things`, `universal_lookup`, `browse_concept_schemes`, `list_concepts`, `list_endpoints`, `get_schema`, `recent_queries` |
| nur Endpoint-Server | 1 | `download` — **derzeit defekt**, siehe „Bekannte Abweichungen" |

Also global 13 + 3 + 7 = **23**, Endpoint 13 + 3 + 1 = **17**. Ohne Schreib-Flag entsprechend 20 und
14: fehlen die drei Schreib-Tools ganz, ist `:mcp: :mounts: :global: :write_enabled:` aus. Das ist kein
„gesperrt", sondern „gibt's nicht" — sie erscheinen dann nicht in `tools/list`
([`setup.md`](setup.md), Schritt 5).

`get_thing` gibt es **nicht** (mehr) — es war identisch mit `get_content`. Wer es in einer alten
Anleitung findet, liest einen überholten Stand.

Der instanzweite `datacycle` kann damit alles, was ein Endpoint-Server kann, inklusive
`search_contents` — er ist nur **unkuratiert** (83 Bäume, `suggest` ~12 s).
Deshalb: instanzweit für „gibt es das überhaupt", ein kuratierter Endpoint für jede Zahl, die
berichtet wird.

## Stufe 3 — Fachliche Abfragen je Server

### `datacycle-tourismus` (POIs & Unterkünfte)

| Frage | Tool + Args | Sollwert |
|---|---|---|
| Wie viele Inhalte hat der Endpoint? | `search_contents {}` | 19.831 |
| Wie viele Betriebe sind buchbar? | `search_contents {"attributes":[{"attribute":"bookable","in":{"bool":true}}]}` | 2.273 |
| … davon mit höchstens 5 Zimmern? | zusätzlich `{"attribute":"numberOfRooms","in":{"max":5}}` | 1.743 |
| Wie viele Inhalte trägt „vegan"? | `resolve_concepts {"term":"vegan"}` → `classification_alias_id_group` in `search_contents` | 4 UUIDs → **81** |
| … „vegetarisch"? | dito | 2 UUIDs → **160** (145 + 15) |
| … „regionale Küche"? | dito | 2 UUIDs → **273** (233 + 40) |

Die Vereinigung ist ein Vorschlag auf Namensbasis: welche Varianten sie einsammelt, hängt am
Datenbestand, die Sollwerte gelten also für den gemessenen Stand und nicht als Zusicherung.

### `datacycle-events`

| Frage | Tool + Args | Sollwert |
|---|---|---|
| Gesamtzahl | `search_contents {}` | 6.244 |
| Events in Lech Zürs | `classification_alias_ids: ["f8320e91-f40e-400f-bc8f-5079e68a84e4"]`, `include_subtree: true` | 1.867 |
| Events außerhalb Lech Zürs | dieselbe UUID als `exclude_classification_alias_ids` | 4.377 |
| **Summenprobe** | 1.867 + 4.377 | **= 6.244 exakt** |
| Termine diese Woche | `schedule: {"from":"<heute>","until":"<+7d>"}` | datumsabhängig, **kein** Sollwert — nur „> 0 und < 6.244" |

Die Summenprobe ist der schärfste Einzeltest im ganzen Katalog: sie schlägt fehl, sobald Scope,
Subtree-Logik oder Seed abweichen.

### `datacycle-touren` (einziger Server mit `Trail`)

| Frage | Tool + Args | Sollwert |
|---|---|---|
| Gesamtzahl | `search_contents {}` | 2.510 |
| Volltext „Wandern" | `{"query":"Wandern","explain":true}` | 1.660, `explain` zeigt `endpoint 2510 → query 1660` |
| Touren bis 15 km | `{"attributes":[{"attribute":"odta:length","in":{"max":15000}}]}` | 1.851 |
| **Einheiten-Gegenprobe** | dieselbe Abfrage mit `"max": 15` | **0** — Meter, nicht Kilometer |
| Die längsten Touren | `{"sort":{"attribute":"odta:length","direction":"desc"},"limit":3}` | 9.978.000 / 3.807.000 / 2.303.000 m |
| Höhenprofil | `elevation_profile {"id":"bdc66596-1d26-4fa7-afd9-e2f6cea77e1e"}` | Punktliste, `meta.scaleX/Y = "m"` |

Die Einheiten-Gegenprobe ist Pflicht: „bis 15 km" als `15` liefert lautlos 0 statt eines Fehlers.

Der Top-Wert der Sortierung (9.978 km für „Niederelbehütte") ist **Datenmüll in der Quelle**, kein
Testfehler — und genau deshalb ein guter Test: `sort_value` samt `sort_unit` steht je Treffer im
Ergebnis und ist zu prüfen, bevor man eine Rangliste berichtet.

### `datacycle-kulinarisches-erbe`

| Frage | Tool + Args | Sollwert |
|---|---|---|
| Gesamtzahl | `search_contents {}` | 110 |
| Nur Rezepte | `{"template_names":["Recipe"]}` | 17 |
| Baum „Kulinarisches Erbe", Ebene 1 | `facet_values` auf den Baum, `min_count_with_subtree: 1` | „Produkte" = 87 mit Subtree, 0 ohne |

### `datacycle-alle-inhalte` (typübergreifend)

| Frage | Tool + Args | Sollwert |
|---|---|---|
| Gesamtzahl | `search_contents {}` | 260.897 |
| Anteil Bilder | `{"template_names":["ImageObject"]}` | 220.957 |
| Rezepte sichtbar? | `{"template_names":["Recipe"]}` | **17** — nicht 0 |
| Typmischung | `{"limit":50}` | **mehrere verschiedene** `template_name` |

Die Rezept-Probe unterscheidet diesen Endpoint vom pool-beschränkten `88bdeca1-…`, der hier 0 liefert
und dabei genauso plausibel aussieht.

### `datacycle` (global, `/api/mcp`)

Nur hier verfügbar — kein Endpoint-Server kann das:

| Frage | Tool + Args | Sollwert |
|---|---|---|
| Welche Endpoints gibt es? | `list_endpoints {}` | Liste inkl. der fünf `MCP Test - …` |
| Was ist diese UUID? | `universal_lookup {"id":"bdc66596-…"}` | `type: "thing"`, `Trail`, „Niederelbehütte" |
| Mehrere IDs auflösen | `select_things {"ids":[…]}` | `count` = Anzahl **auflösbarer** IDs |
| Baum suchen | `browse_concept_schemes {"search":"Regionen"}` | „Regionen Vorarlberg", 24 Concepts |
| Concepts eines Baums | `list_concepts {"concept_scheme_id":"ec5592d1-…"}` | „Tourismusdestination" = 20.845, „Sonstige" = 1.128 |
| Lesendes Schema | `get_schema {"template":"Trail"}` | `type/title/properties/required` |
| Was habe ich gefragt? | `recent_queries {"limit":5}` | eigene Calls samt `endpoint` |
| Bestand über Zeit | `statistics {"attribute":"dct:modified","group_by":"year"}` | Jahresreihe |

`statistics` akzeptiert als `attribute` **nur** `dct:created`/`dct:modified` und als `group_by` nur
Zeiteinheiten (`hour`…`year`). Es ist kein Aggregat über Fachattribute — „Durchschnittslänge der
Touren" ist damit nicht beantwortbar.

## Stufe 4 — Fallenabfragen (müssen fehlschlagen bzw. auffallen)

Diese Tests prüfen nicht, ob etwas funktioniert, sondern ob eine **falsche Antwort erkennbar** ist.

| Test | Abfrage | Erwartung |
|---|---|---|
| **`place` mit Fantasieort** | `search_contents {"place":"Quatschort"}` | liefert die **Gesamtmenge** (19.831 / 260.897 / 6.244) — stiller No-Op, kein Fehler |
| `resolve_place` vorschalten | `resolve_place {"place":"Quatschort"}` | `resolved: false` — nur so wird der No-Op sichtbar |
| Gemeinde-Ebene | `resolve_place {"place":"Bregenz"}` | `resolved: false` — **auch für echte Orte**, siehe unten |
| Bundesland-Ebene | `resolve_place {"place":"Vorarlberg"}` | `resolved: true`, `coverage.classification: 13.271` |
| Erfundene Alias-UUID | eine rekonstruierte UUID als `classification_alias_ids` | landet in `unresolved_ids`; positiver Filter → 0, negativer → Gesamtmenge |
| Falsche Einheit | `odta:length max 15` statt `15000` | 0 Treffer statt Fehler |
| API-Name beim Schreiben | `create_content` mit `odta:length` statt `length` | Datensatz wird angelegt, Wert **verworfen** → `ignored_attributes` prüfen |

Merksatz für alle sechs Server: **jede Filterabfrage gegen die ungefilterte Gesamtzahl gegenprüfen.**
Ein Filter, der die Gesamtmenge zurückgibt, hat nicht gefiltert.

## Stufe 5 — Schreibende Tools

Nur freigeschaltet, wenn das Instanz-Repo `write_enabled` setzt ([`setup.md`](setup.md), Schritt 5) —
in `data-cycle-vcloud-dev` nur für `Rails.env development`.
Der Rauchtest **legt echte Daten an** — bewusst ausführen:

```bash
dcmcp /api/mcp create_content '{"template_name":"Trail","data":{"name":"Testtour","ascent":420,"length":9500},"locale":"de"}'
```

Prüfen, in dieser Reihenfolge:

1. `ignored_attributes` ist **leer** — sonst wurden Werte still verworfen.
2. `attribute_name_corrections` ist leer — sonst wurden API-Namen statt interner Keys geschickt.
3. Anschließende Suche nach „Testtour" liefert **0 Treffer**. Das ist korrekt: neue Inhalte landen im
   Pool „Entwurf" und sind in keinem Endpoint sichtbar.

Attributnamen immer aus `list_writable_attributes {"template_name":"Trail"}` — dort steht `attribute`
(schreibbar) neben `api_name` (lesend). `get_schema` liefert nur die lesenden Namen.

## Prompts zum Kopieren

Dieselben Tests als Prompt für eine Claude-Code-Session — zum Durchklicken, ohne curl. Sie prüfen mehr
als die Roh-Calls: nämlich auch, ob das Modell das **richtige Tool mit den richtigen Argumenten** wählt.

Den Server im Prompt benennen, sonst greift Claude zum erstbesten passenden Tool — die Tools sind pro
Server benannt (`mcp__datacycle-touren__search_contents`), und derselbe Fachbegriff liefert je Server
eine andere Zahl. Immer die Zahl **und** das benutzte Tool nennen lassen, sonst ist nicht prüfbar, ob
das Ergebnis aus dem gemeinten Scope kommt.

Ein Prompt, der jedem Einzeltest vorangestellt werden kann:

> Nenne bei jeder Antwort den Server, das Tool und die Argumente, die du benutzt hast, und vergleiche
> die Trefferzahl mit der ungefilterten Gesamtzahl desselben Servers.

### Tourismus

| Prompt | Sollantwort |
|---|---|
| „Wie viele Inhalte hat der Endpoint `datacycle-tourismus` insgesamt?" | 19.831 |
| „Wie viele buchbare Betriebe gibt es in `datacycle-tourismus`?" | 2.273 |
| „Und wie viele davon haben höchstens 5 Zimmer?" | 1.743 |
| „Welche Betriebe in `datacycle-tourismus` bieten vegane Küche? Nenn mir die Anzahl." | 81, über die Vereinigung aller vier Varianten — **nicht** ein einzelnes Concept |
| „… vegetarische Küche?" | 160 (145 + 15) |
| „… regionale Küche?" | 273 (233 + 40) |

Bei den drei Küche-Prompts ist die Zahl nur die halbe Prüfung: Claude muss `resolve_concepts` benutzen
und die **ganze** `classification_alias_id_group` übergeben. Nennt die Antwort nur eine UUID, ist das
Ergebnis zu niedrig — auch wenn es plausibel aussieht.

### Events

| Prompt | Sollantwort |
|---|---|
| „Wie viele Events hat `datacycle-events`?" | 6.244 |
| „Wie viele Events finden in Lech Zürs statt?" | 1.867 |
| „Und wie viele finden außerhalb von Lech Zürs statt?" | 4.377 — muss sich mit der vorigen Antwort zu 6.244 addieren |
| „Welche Veranstaltungen laufen in den nächsten 7 Tagen?" | `schedule`-Filter, Zahl datumsabhängig; falsch ist eine Antwort ohne `schedule` |

### Touren

| Prompt | Sollantwort |
|---|---|
| „Wie viele Touren hat `datacycle-touren`?" | 2.510 |
| „Wie viele Touren sind maximal 15 km lang?" | **1.851** — Claude muss auf 15000 (Meter) umrechnen. Antwortet es 0, hat es „15" durchgereicht |
| „Was sind die drei längsten Touren?" | muss `sort` benutzen (nicht `limit` allein) **und** anmerken, dass der Top-Wert mit 9.978 km unplausibel ist |
| „Zeig mir das Höhenprofil der Tour Niederelbehütte." | `elevation_profile`, Punktliste in Metern |
| „Wie viele Touren wurden pro Jahr geändert?" | `statistics` mit `dct:modified`/`year`: 2023 = 150, 2024 = 1.704, 2025 = 656 |

Der 15-km-Prompt ist der wichtigste Einzeltest der Suite: er prüft die Einheitenumrechnung, und ein
Fehler äußert sich als glatte 0 statt als Fehlermeldung.

### Kulinarisches Erbe

| Prompt | Sollantwort |
|---|---|
| „Wie viele Inhalte hat `datacycle-kulinarisches-erbe`?" | 110 |
| „Wie viele davon sind Rezepte?" | 17 |
| „Wie ist der Baum ‚Kulinarisches Erbe' aufgebaut?" | `facet_values`; „Produkte" = 87 mit Subtree, 0 ohne |

### Alle Inhalte (typübergreifend)

| Prompt | Sollantwort |
|---|---|
| „Wie viele Inhalte gibt es insgesamt, unabhängig vom Inhaltstyp?" | 260.897 über `datacycle-alle-inhalte` oder `datacycle` |
| „Wie viele davon sind Bilder?" | 220.957 |
| „Gibt es Rezepte in `datacycle-alle-inhalte`?" | 17 — **nicht 0** |
| „Zeig mir 50 beliebige Inhalte mit ihrem Typ." | mehrere verschiedene `template_name` |
| „Finde alle Inhalte zum Thema Familienurlaub, egal welcher Inhaltstyp." | mehrere Bäume durchsucht, Aliases in **einer** Abfrage vereint, Treffer über `LodgingBusiness`/`Event`/`Trail`/`TouristAttraction` verteilt |

Der Familienurlaub-Prompt ist der Integrationstest für typübergreifende Abfragen: ein Concept dieses
Namens existiert nicht, Claude muss die thematischen Aliases aus mehreren Bäumen selbst
zusammenstellen. Eine Antwort aus einem einzigen Baum ist zu niedrig.

### Global (`datacycle`)

| Prompt | Sollantwort |
|---|---|
| „Welche MCP-Endpoints gibt es in dieser Instanz?" | `list_endpoints`, enthält die fünf `MCP Test - …` |
| „Was verbirgt sich hinter der ID `bdc66596-1d26-4fa7-afd9-e2f6cea77e1e`?" | `Trail` „Niederelbehütte" |
| „Welche Klassifikationsbäume haben ‚Regionen' im Namen?" | „Regionen Vorarlberg", 24 Concepts |
| „Welche Concepts hat der Baum ‚Regionen Vorarlberg' und wie viele Inhalte hängen dran?" | „Tourismusdestination" 20.845, „Sonstige" 1.128 |
| „Welche Attribute kann ich bei einem `Trail` schreiben?" | `list_writable_attributes`: `attribute` (interner Key) neben `api_name` |

### Fallen-Prompts

Hier ist die **falsche** Antwort plausibel — genau das wird geprüft.

| Prompt | Richtig | Falsch (aber plausibel) |
|---|---|---|
| „Wie viele Unterkünfte gibt es in Quatschort?" | „Der Ort ist nicht auflösbar" — `resolve_place` → `resolved: false` | „19.831" (die Gesamtmenge, weil `place` still nicht gefiltert hat) |
| „Wie viele POIs gibt es in Bregenz?" | Hinweis, dass `resolve_place` auch für Bregenz fehlschlägt | irgendeine Zahl ohne Auflösungsprüfung |
| „Wie viele Touren sind maximal 15 km lang?" | 1.851 | 0 |
| „Was ist die längste Tour Vorarlbergs?" | „Niederelbehütte" **mit** dem Hinweis, dass 9.978 km Datenmüll ist | „Niederelbehütte, 9.978 km" ohne Kommentar |
| „Wie viele Events gibt es in der Kategorie <erfundene UUID>?" | Hinweis auf `unresolved_ids` | 0 (positiver Filter) bzw. 6.244 (negativer Filter) |
| „Lade die Tour Niederelbehütte als GPX herunter." | Fehlermeldung zum defekten `download` | eine erfundene Datei-URL |

## Bekannte Abweichungen (Stand 04.08.2026)

- **Jeder Klassifikationsfilter schlägt fehl, solange die DB nicht migriert ist (gemessen
  10.08.2026).** Symptom auf allen sechs Servern: `{"errors":[{"title":"Invalid request"}]}`. Im
  Activity-Log der Anfrage steht die Ursache — `PG::UndefinedColumn: column ccc1.hidden does not
  exist`. Die Spalte legt `20260706100000 AddHiddenToClassificationMappings` an; in
  `data-cycle-vcloud-dev` standen dazu **13 Migrationen aus**, weil der Gem-Stand vorgezogen wurde
  und die DB nicht mitgewandert ist. Betroffen: `resolve_concepts` (mit `term`), `facet_values`,
  `list_concepts` **und** `search_contents` mit `classification_alias_ids`,
  `classification_alias_id_groups`, `include_subtree` oder `exclude_classification_alias_ids`.
  Damit fallen Stufe 3 (Lech-Zürs-Summenprobe, die drei Küche-Begriffe) und Stufe 4 teilweise aus.
  Weiter testbar: `search_contents` ohne Klassifikationsfilter, Attributfilter, Volltext,
  `list_templates`, `list_facets`, `resolve_place`.
  **Die Falle dabei:** der Fehler tritt nur auf, wenn Concepts *gefunden* werden — die Zählabfrage
  mit `ccc1.hidden` läuft sonst nicht. `resolve_concepts term:"vegan"` antwortet auf
  `datacycle-events` sauber mit 0 Concepts und auf `datacycle-tourismus` mit einem Fehler. Das sieht
  nach einem sprunghaften, term-abhängigen Serverfehler aus und ist keiner. Prüfen mit
  `rails db:migrate:status`, nicht durch Variieren des Suchbegriffs.
- **`download` ist defekt.** Auf jedem Endpoint-Server:
  `undefined method 'api_v4_download_thing_path'`. Das Tool steht in `tools/list`, ist aber nicht
  aufrufbar — der Route-Helper fehlt. Betrifft alle Formate.
- **`resolve_place` löst keine Gemeinden auf.** „Bregenz" → `resolved: false`, obwohl der Baum
  „Administrative Einheiten" 14.920 Gemeinden führt; „Vorarlberg" und „Steiermark" lösen auf. Ortsfilter
  auf Gemeindeebene sind damit derzeit nicht verlässlich.
- **Touren-Gesamtzahl 2.510 statt 2.508** (+2 gegenüber dem Stand vom 31.07.2026). Kleiner Zuwachs,
  kein Scope-Fehler — die Einheiten- und `explain`-Proben treffen weiter. Wer in einer älteren Notiz
  2.508 findet, hat keinen Fehler gefunden.
- **`search_contents.attributes` hat eine neue Signatur.** Neu:
  `[{"attribute":"bookable","in":{"bool":true}}]`. Die alte Form `[{"bookable":{"bool":true}}]` wird
  jetzt mit `disallowed additional property` abgewiesen — älteren Beispielcode entsprechend anpassen.
- **`timeseries` findet in dieser DB keine Daten.** Geprüft mit `Trail` und mit zwei
  `SnowReportLocation` (dem naheliegenden Messreihen-Template, 100 Inhalte): jedes Mal
  `no timeseries data found`. Das Tool ist damit nicht sinnvoll testbar, solange keine Messreihe
  importiert ist — nicht als Serverfehler werten.
