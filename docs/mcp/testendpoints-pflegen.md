# MCP-Testendpoints anlegen und ändern

Rezept für jede Änderung an den MCP-Testendpoints — als nachvollziehbares Muster, nicht als
einmaliges Skript. Client-seitige Einrichtung: [`setup.md`](setup.md). Sollwerte zum Verifizieren:
[`testabfragen.md`](testabfragen.md).

## Grundprinzip: alles läuft über das `db/seeds.rb` des Instanz-Repos, nichts manuell in der DB

Alle MCP-Testendpoints sind `DataCycleCore::StoredFilter`-Records mit `api: true`. Sie werden
**ausschließlich** im `db/seeds.rb` der jeweiligen Instanz definiert und über `rails db:seed`
angewendet — niemals direkt per Rails-Konsole oder Admin-UI anlegen/ändern, sonst geht die Änderung
beim nächsten Merge/Restore wieder verloren (siehe Fallstrick unten).

**Nicht im Gem.** Templates, Klassifikationsbäume und damit auch der sinnvolle Scope eines Endpoints
sind pro Instanz verschieden; ein Endpoint, den `data-cycle-core` seedet, trägt die UUIDs genau einer
Instanz in jede andere. Die Engine liefert deshalb keine Endpoints aus, dieses Rezept ist ihr Ersatz.
Gemessen und geschrieben wurde alles gegen `data-cycle-vcloud-dev`.

Der Seed-Block gehört unter `if ['development', 'review'].include?(Rails.env)` und iteriert über ein
Array von Hashes (`id`, `name`, `parameters`, optional `concept_scheme_ids`).
Für jeden Eintrag:

```ruby
stored_filter = DataCycleCore::StoredFilter.find_or_initialize_by(id: attrs[:id])
stored_filter.name = attrs[:name]
stored_filter.api = true
stored_filter.user = mcp_test_endpoint_owner
stored_filter.parameters = attrs[:parameters]
stored_filter.concept_scheme_ids = attrs[:concept_scheme_ids].to_a
stored_filter.save!
```

Drei Details, die jeweils einen konkreten Fehler verhindern:

- `find_or_initialize_by` + `save!`, **nicht** `find_or_create_by!` mit Block — der Block läuft nur
  beim erstmaligen Anlegen, wodurch spätere Parameter-Änderungen an einem bereits existierenden Record
  nie ankämen.
- `concept_scheme_ids` wird **immer** zugewiesen, auch leer: sonst behält ein bestehender Endpoint
  eine zurückgenommene Kuratierung und liefert eine Auswahl aus, die im Code nicht mehr steht.
- Kuratierte UUIDs, die die lokale DB nicht führt, werden **übersprungen und benannt** statt zugewiesen
  (`ConceptScheme.where(id: …).pluck(:id)`). `concept_scheme_ids=` ist eine has_many-through-Zuweisung
  und würde für eine unbekannte UUID `ActiveRecord::RecordNotFound` werfen — `db:seed` brach damit auf
  jeder Instanz ab, deren DB diese Bäume nicht hat, und zwar **vor** allen folgenden Seeds. Eine
  Meldung „N kuratierte concept_scheme_ids nicht in dieser DB … übersprungen" im Seed-Log ist also
  erwartbar und kein Abbruch — aber ein Hinweis, dass `list_facets` dort weniger zeigt.

## Schritt-für-Schritt: neuen Endpoint hinzufügen (Beispiel KulinarischesErbe)

1. **Feste UUID wählen** — z. B. per `SecureRandom.uuid` einmal generieren, dann hart in `seeds.rb`
   eintragen. Fest, damit die URL `/api/v4/endpoints/<uuid>/mcp` über alle lokalen DBs (Kolleg:innen,
   CI, Restores) identisch bleibt.
2. **Templates bestimmen, die den Anwendungsfall abdecken.** Für KulinarischesErbe initial nur
   `Recipe` — das hat sich als zu eng erwiesen, weil `CulinaryHeritage` (88 Vorarlberg-Themen wie
   Alpe/Sennerei/Bodensee-Fisch) und `FoodEstablishment` (5) dadurch komplett unsichtbar wurden,
   obwohl Content existiert. Prüfen mit:

   ```ruby
   DataCycleCore::Thing.where(template_name: 'CulinaryHeritage').count
   ```

   vor dem Erweitern der Liste, um zu bestätigen, dass sich das Ausweiten lohnt.

   **Nur `content_type: 'entity'`-Templates aufnehmen.** `RecipeComponent`/`RecipeIngredient` standen
   zunächst mit in der Liste, sind aber `embedded` — der Endpoint filtert
   `where.not(content_type: 'embedded')`, die Einträge waren also wirkungslos und wurden am
   2026-07-31 entfernt. Embedded Templates werden ohnehin inline über ihren Träger serialisiert. Vor
   dem Aufnehmen prüfen:

   ```ruby
   DataCycleCore::ThingTemplate.find_by(template_name: 'RecipeIngredient').content_type
   ```
3. **Hash-Eintrag in `seeds.rb` ergänzen**, mit kurzem Kommentar, WARUM genau diese Templates (nicht
   was sie tun — das steht im Code):

   ```ruby
   {
     id: 'c9de1115-1459-4c91-ba09-cffb53d68bb4',
     name: 'KulinarischesErbe',
     # war bewusst auf Recipe beschränkt, hat dadurch aber CulinaryHeritage und die anderen
     # kulinarischen Templates komplett ausgeblendet, obwohl dazu Inhalte existieren.
     parameters: [{ 'c' => 'd', 't' => 'template_names', 'v' => ['Recipe', 'CulinaryHeritage', 'FoodEstablishment'] }]
   }
   ```
4. **`concept_scheme_ids` setzen** — der Schlüssel ist technisch optional, praktisch aber Pflicht:
   fehlt er, fällt `list_facets` auf ALLE abgeleiteten Bäume zurück, inklusive der
   Herkunfts-/Technikbäume (Inhaltspools, Ausgabekanäle, Lizenzen, Tags, TestSchema, Öffnungsstatus,
   Ländercodes), die Regel (3) der Kuratierung gerade ausschließt.

   Es gelten drei Auswahlregeln: (1) nur Bäume, die in diesem Scope Inhalte tragen, (2) genau ein
   Baum je Dimension — von mehreren konkurrierenden gewinnt der mit der besseren Abdeckung, (3) keine
   Herkunfts-/Technikbäume. Jede bewusste Abweichung gehört als Kommentar an den Eintrag, weil sie
   sonst beim nächsten Aufräumen zurückgedreht wird.

   > **Offener Punkt:** `KulinarischesErbe` hat als einziger Endpoint **keine** `concept_scheme_ids`
   > und zeigt deshalb 14 abgeleitete Bäume statt einer Auswahl (gemessen 04.08.2026). Wer den
   > Endpoint das nächste Mal anfasst, zieht die Kuratierung nach.
5. **Seed anwenden:**

   ```bash
   # Container läuft:
   docker compose exec web bash -c "bin/rails db:seed"
   # Container läuft nicht:
   docker compose run --rm web bash -c "bin/rails db:seed"; docker compose stop
   ```

   Der Service heißt `web` (nicht `app`); unter Linux/Flatpak jeweils `flatpak-spawn --host`
   voranstellen.
6. **Verifizieren**, dass der Record existiert und `api: true` hat:

   ```sql
   SELECT id, name, api FROM collections WHERE id = 'c9de1115-1459-4c91-ba09-cffb53d68bb4';
   ```
7. **MCP-Server registrieren** und neu verbinden — Ablauf, Platzhalter und Reconnect stehen in
   [`setup.md`](setup.md), Schritt 3. Der Reconnect ist eine Harness-Aktion, die Claude nicht selbst
   auslösen kann.
8. **Sollwert festhalten:** die neue Zeile in [`testabfragen.md`](testabfragen.md) (Stufe 1, plus eine
   fachliche Abfrage in Stufe 3) ergänzen. Ein Endpoint ohne Sollwert ist nach dem nächsten Restore
   nicht mehr prüfbar.

## Schritt-für-Schritt: bestehenden Endpoint ändern (Beispiel Tourismus)

Gleiche Datei, gleiches Muster — **nicht** einen neuen Hash-Eintrag anlegen, sondern den bestehenden
Eintrag mit der gleichbleibenden `id` bearbeiten:

1. Grund für die Änderung konkret machen (welche Frage lief ins Leere?). Bei Tourismus:
   `LodgingBusiness` fehlte, wodurch jede "buchbar / Anzahl Zimmer"-Frage 0 Treffer lieferte, weil nur
   dieses Template die `advanced_search`-Attribute `bookable`/`numberOfRooms` trägt. Später zusätzlich
   `BlogPost`/`StructuredArticle`, damit redaktionelle Begleitartikel zu Destinationen auffindbar sind.
2. Nur die `parameters`-Zeile (bzw. `concept_scheme_ids`) des betroffenen Hash-Eintrags anpassen, `id`
   unverändert lassen.
3. `rails db:seed` erneut laufen lassen — der bestehende Record wird per `find_or_initialize_by(id:)`
   gefunden und mit den neuen `parameters` überschrieben, nicht dupliziert.
4. Config in `~/.claude.json` bleibt unverändert, da die UUID gleich bleibt.

## Fallstrick: der Seed-Block ist ein Array — ein fremder Merge kann Einträge stillschweigend killen

Am 2026-07-28 — die Endpoints lagen damals noch im Gem — hat ein unabhängiger Commit (`111b58b4f`,
Ticket #49217, unrelated zu MCP) dessen `db/seeds.rb` umfassend umgeschrieben, um
`concept_scheme_ids` und einen neuen "MCP Test - Touren"-Endpoint einzuführen — dabei ist der
`KulinarischesErbe`-Hash-Eintrag und die `BlogPost`/`StructuredArticle`-Erweiterung beim
Tourismus-Eintrag ersatzlos aus dem Array gefallen (vermutlich Merge-Konflikt,
falsch aufgelöst). **Der StoredFilter blieb trotzdem in der DB bestehen** — `db:seed` löscht nie,
sondern nur `find_or_initialize_by` + überschreiben für Records, die im Array stehen. Der MCP-Server
lief also unauffällig weiter, obwohl der Code ihn nicht mehr kennt. Konsequenz: bei einem **frischen**
DB-Restore/Seed (neue lokale DB, CI) wäre der Endpoint nicht mehr da bzw. der Tourismus-Endpoint
wieder ohne `BlogPost`/`StructuredArticle` — ohne dass ein Fehler auffällt, weil `db:seed` idempotent
und fehlerfrei durchläuft. Beide Einträge wurden deshalb wiederhergestellt (2026-07-28).

Lehre: nach jedem Merge, der `db/seeds.rb` berührt, den MCP-Testendpoint-Block auf Vollständigkeit
prüfen, nicht nur auf Syntaxfehler. Ein `git diff` gegen den vorherigen Stand des Arrays zeigt fehlende
Einträge sofort; als schneller Zähler:

```bash
grep -c "id: '" db/seeds.rb   # erwartet: 5
```

Erwartet sind aktuell **fünf** Einträge: Tourismus, Events, Touren, KulinarischesErbe, Alle Inhalte.
Die Zahl hier mitpflegen, wenn ein Endpoint dazukommt — sonst prüft der Befehl gegen einen veralteten
Sollwert und meldet nichts.

## Referenzen

- `db/seeds.rb` des Instanz-Repos — einzige Quelle der Wahrheit für alle Testendpoints
- Commits `a219fd262` / `0a74e91cb` — Ursprung von KulinarischesErbe bzw. der Tourismus-Erweiterung
- Commit `111b58b4f` — Regression, die beide wieder entfernt hat (seitdem in `seeds.rb` erneut ergänzt)
- [`setup.md`](setup.md) — Client-seitige Einrichtung in Claude Code
- [`testabfragen.md`](testabfragen.md) — Sollwerte, gegen die eine Seed-Änderung zu prüfen ist
