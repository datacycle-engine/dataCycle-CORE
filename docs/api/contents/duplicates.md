# Datenschnittstelle für Duplikatskandidaten

Die Duplikatskandidaten eines Inhaltes können über die APIv4 gelesen und bearbeitet werden: Paare abrufen, ein Paar manuell als Duplikate markieren, ein Paar zusammenführen und ein Paar als falsch erkanntes Duplikat (False Positive) verwerfen. Das entspricht den Aktionen der Dublettenbearbeitung im Backend und verwendet dieselbe Berechtigung `merge_duplicates`.

Voraussetzung ist das aktivierte Feature `duplicate_candidate`; andernfalls antworten alle Endpunkte mit `404`.

> Ein Inhaltspaar kann mehrere Kandidaten-Datensätze haben — einen pro Erkennungsmethode. In der Datenschnittstelle wird pro Duplikat *ein* Eintrag ausgespielt, mit dem höchsten Score und allen Methoden, die das Paar gefunden haben.

## Duplikatskandidaten abrufen

#### HTTP-GET:

```url
/api/v4/things/<THING-ID>/duplicates?token=YOUR_ACCESS_TOKEN
```

Unterstützte Parameter:

| Parameter | Bedeutung |
|---|---|
| `page[size]`, `page[number]` | Standard-Paging; ein zusätzliches `page[offset]` verschiebt die Seite |
| `page[limit]`, `page[offset]` | Standard-Paging, hat Vorrang vor `page[size]`/`page[number]` |
| `section[meta]` | `0` lässt `meta` weg und spart die Zählabfrage |
| `falsePositive` | `true` liefert die verworfenen Paare statt der aktiven |
| `language` | Sprache für `name` der Duplikate; pro Duplikat wird die beste verfügbare Übersetzung verwendet |

Die übrigen Standard-Parameter der APIv4 (`include`, `fields`, `sort`, …) werden akzeptiert, wirken auf diese Endpunkte aber nicht: die Sortierung ist fix `dc:score` absteigend, bei gleichem Score die `@id` — dadurch bleibt das Paging über gleich bewertete Kandidaten stabil.

Rückgabewert:

```json
{
  "@id": "9b8e4a1c-0000-4000-8000-000000000000",
  "meta": { "total": 1, "pages": 1 },
  "dc:duplicates": [
    {
      "@id": "3f2b7c55-0000-4000-8000-000000000000",
      "@type": ["Place", "dcls:POI"],
      "name": "Gasthof zur Post",
      "dct:modified": "2026-07-30T09:12:44.123+02:00",
      "dc:score": 100.0,
      "dc:duplicateMethod": ["manual", "only_title"],
      "dc:falsePositive": false
    }
  ]
}
```

Die Kandidaten sind nach `dc:score` absteigend sortiert. Verworfene Paare sind standardmäßig nicht enthalten.

## Duplikat manuell markieren

Markiert zwei Inhalte desselben Typs explizit als Duplikate. Die Markierung wird als eigener Kandidat mit der Methode `manual` und Score 100 gespeichert, *neben* allen automatisch erkannten Kandidaten des Paares, und bleibt bei der automatischen Neuberechnung der Duplikatskandidaten erhalten.

War das Paar zuvor als False Positive verworfen, wird es dadurch wieder aktiv.

#### HTTP-POST:

```url
/api/v4/things/<THING-ID>/duplicates
```
JSON-Body:
```json
{
  "token": "YOUR_ACCESS_TOKEN",
  "@id": "3f2b7c55-0000-4000-8000-000000000000"
}
```

Antwort: `201` wenn das Paar neu markiert wurde, `200` wenn es bereits manuell markiert war. Der Body entspricht dem des GET-Endpunktes.

## Duplikat zusammenführen

Führt das Duplikat in den Inhalt zusammen. Die Zusammenführung läuft asynchron (`MergeDuplicateJob`), damit die Antwortzeit nicht von der Anzahl der zu verschiebenden Verlinkungen abhängt. Vorher wird auf dem Zielinhalt eine benannte Version geschrieben, die den Merge dokumentiert.

#### HTTP-POST:

```url
/api/v4/things/<THING-ID>/duplicates/<DUPLICATE-ID>/merge
```

Antwort: `202`. Das Paar verschwindet unmittelbar aus den Duplikatskandidaten.

## Duplikat verwerfen (False Positive)

Markiert das Paar als falsch erkannt. Es verschwindet aus den Duplikatskandidaten und wird auch von der automatischen Neuberechnung nicht wieder aufgenommen. Über `falsePositive=true` ist es weiterhin abrufbar und kann durch erneutes manuelles Markieren reaktiviert werden.

#### HTTP-POST:

```url
/api/v4/things/<THING-ID>/duplicates/<DUPLICATE-ID>/false_positive
```

Antwort: `200`, Body wie beim GET-Endpunkt.

> Duplikatskandidaten werden ausschließlich über den oben beschriebenen Endpunkt ausgespielt. Inhalts-Antworten (`/api/v4/things/<THING-ID>`, Datenendpunkte) enthalten sie nicht — auch nicht über `include`.

## Inhalte mit Duplikatskandidaten filtern — **filter\[duplicateCandidates\]**

Damit lässt sich eine Arbeitsliste für die Dublettenprüfung aufbauen, ohne dafür einen Datenendpunkt vorkonfigurieren zu müssen.

| Parameter | Bedeutung |
|---|---|
| `filter[duplicateCandidates][exists]` | `true` = nur Inhalte mit Kandidaten, `false` = nur Inhalte ohne (`1`/`0`, `t`/`f`, `on`/`off` ebenso) |
| `filter[duplicateCandidates][minScore]` | Mindest-Score |
| `filter[duplicateCandidates][maxScore]` | Höchst-Score |
| `filter[duplicateCandidates][method]` | Erkennungsmethode, z.B. `manual` oder `only_title` |

#### HTTP-GET:

```url
/api/v4/endpoints/<ENDPOINT-ID>?filter[duplicateCandidates][exists]=true&filter[duplicateCandidates][minScore]=80
```

Die gefilterte Liste nennt die betroffenen Inhalte; die Kandidaten dazu holt man pro Inhalt über den Duplikats-Endpunkt.

## Berechtigungen und Sichtbarkeit

Alle Endpunkte verlangen die Berechtigung `merge_duplicates` für **beide** beteiligten Inhalte. Zusätzlich muss sich jeder der beiden Inhalte innerhalb des API-Scopes des Aufrufers befinden (die für die Rolle konfigurierten `api`-User-Filter); Kandidaten außerhalb des Scopes werden aus der Liste gefiltert, ein Inhalt außerhalb des Scopes wird mit `401` abgelehnt. Das ist wesentlich, weil `@id` beim Markieren frei wählbar ist: ohne diese Prüfung wäre der Endpunkt eine Titelabfrage für beliebige Inhalte derselben Vorlage.

Vom Scope-Filter wird ausschließlich die **Gültigkeits-Komponente** übergangen (`validity_period`, `in_validity_period` und ihre Negationen): ein Werkzeug zur Dublettenprüfung muss auch abgelaufene Inhalte erreichen können. Die Zugriffsbeschränkung selbst (Mandant, Inhaltspools, Freigaben) gilt unverändert. Das gilt auf jeder Verschachtelungsebene — auch wenn der Scope über eine gespeicherte Sammlung (`filter_ids`, `union_filter_ids`) oder einen `union`-Parameter konfiguriert ist, deren Gültigkeitsparameter innerhalb eines eigenen Filters liegen.

Eingebettete Inhalte können keine Duplikate haben — die automatische Erkennung läuft für sie nicht — und werden deshalb noch vor der Scope-Prüfung mit `422` abgelehnt (siehe Fehlerbehandlung), unabhängig davon, ob für den Aufrufer ein API-Scope konfiguriert ist.

`merge_duplicates` darf nur an interne API-Rollen vergeben werden. Achtung: die Berechtigung war bisher rein backendseitig — jede bestehende Rolle, die sie hält, kann mit diesen Endpunkten auch über die API Duplikate markieren und zusammenführen.

## Fehlerbehandlung

| Status | Bedeutung |
|---|---|
| `400` | `@id` fehlt beim Markieren |
| `401` | keine Berechtigung, Inhalt oder Duplikat außerhalb des API-Scopes (bzw. nicht authentifiziert) |
| `404` | Inhalt oder Duplikat existiert nicht, oder das Feature `duplicate_candidate` ist deaktiviert |
| `422` | beide Seiten sind derselbe Inhalt, die Inhaltstypen unterscheiden sich, oder ein eingebetteter Inhalt ist beteiligt |

Fehler werden im Format der APIv4 ausgespielt:

```json
{
  "errors": [
    {
      "source": { "pointer": "/api/v4/things/<THING-ID>/duplicates" },
      "detail": "template mismatch: POI != Bild"
    }
  ]
}
```
