# Datenschnittstelle für externe Verknüpfungen

Die externen Verknüpfungen eines Inhaltes können über die APIv4 verwaltet werden: hinzufügen, entfernen, zum Primärsystem hochstufen (promote) und das Primärsystem zur Verknüpfung herabstufen (demote). Das entspricht den Aktionen, die im Backend in der Liste der externen Verknüpfungen zur Verfügung stehen, und verwendet auch dieselben Berechtigungen.

Die aktuellen Verknüpfungen eines Inhaltes werden von der Datenschnittstelle unter `identifier` ausgespielt (siehe [Verknüpfung zu externen Systemen](/docs/external_references)). Genau diese Werte werden zum Adressieren einer Verknüpfung verwendet:

| Parameter | Bedeutung |
|---|---|
| `propertyID` | Identifier, Name oder UUID des externen Systems |
| `value` | Externer Schlüssel (`external_key`) |

Ein Request betrifft immer genau einen Inhalt und eine Verknüpfung. Die interne ID einer Verknüpfung wird nicht benötigt.

> Nicht zu verwechseln mit `PATCH /api/v4/external_sources/<EXTERNAL-SOURCE-ID>/demote`: dort kann ein importierendes System mehrere **eigene** Inhalte auf einmal herabstufen (über die konfigurierte `api_strategy`). Die hier beschriebenen Endpunkte arbeiten inhaltsbezogen und im Namen eines Benutzers.

## Verknüpfung hinzufügen

Legt eine Verknüpfung vom Typ `duplicate` an. Der Aufruf ist idempotent: existiert die Verknüpfung schon, bleibt sie unverändert.

Existiert für dasselbe System und denselben Schlüssel bereits eine Verknüpfung vom Typ `import` oder `export`, antwortet der Endpunkt mit `422`. Andernfalls würde dasselbe `propertyID`/`value`-Paar zweimal im `identifier`-Output erscheinen.

#### HTTP-POST:

```url
/api/v4/things/<THING-ID>/external_connections
```
JSON-Body:
```json
{
  "token": "YOUR_ACCESS_TOKEN",
  "propertyID": "feratel",
  "value": "ABC-123"
}
```

## Verknüpfung entfernen

Entfernt eine Verknüpfung vom Typ `duplicate`. Ebenfalls idempotent: ist die Verknüpfung nicht (mehr) vorhanden, wird der aktuelle Stand ohne Fehler zurückgegeben.

#### HTTP-DELETE:

```url
/api/v4/things/<THING-ID>/external_connections?propertyID=feratel&value=ABC-123&token=YOUR_ACCESS_TOKEN
```

## Verknüpfung zum Primärsystem hochstufen

Macht eine bestehende Verknüpfung zum primären externen System des Inhaltes. Das bisherige Primärsystem bleibt als Verknüpfung vom Typ `duplicate` erhalten, es gehen also keine Daten verloren.

#### HTTP-PATCH:

```url
/api/v4/things/<THING-ID>/external_connections/promote
```
JSON-Body:
```json
{
  "token": "YOUR_ACCESS_TOKEN",
  "propertyID": "feratel",
  "value": "ABC-123"
}
```

## Primärsystem herabstufen

Wandelt das primäre externe System des Inhaltes in eine Verknüpfung vom Typ `duplicate` um. Danach hat der Inhalt kein Primärsystem mehr, der externe Schlüssel bleibt erhalten.

#### HTTP-PATCH:

```url
/api/v4/things/<THING-ID>/external_connections/demote
```
JSON-Body:
```json
{
  "token": "YOUR_ACCESS_TOKEN"
}
```

## Rückgabewert

Alle vier Endpunkte liefern den aktuellen Verknüpfungsstand des Inhaltes zurück, ein zweiter Request zum Auslesen ist nicht notwendig:

```json
{
  "@id": "9b8e4a1c-0000-4000-8000-000000000000",
  "identifier": [
    {
      "@type": "PropertyValue",
      "propertyID": "feratel",
      "value": "ABC-123",
      "valueReference": "duplicate"
    }
  ]
}
```

`valueReference` gibt die Art der Verknüpfung an: `import` für das Primärsystem, `duplicate` für weitere Verknüpfungen, `export` für Verknüpfungen aus einem Export.

## Berechtigungen

Es gelten die Backend-Berechtigungen für Inhalte, die pro Rolle konfiguriert werden:

| Endpunkt | Berechtigung |
|---|---|
| hinzufügen | `create_external_connection` |
| entfernen | `remove_external_connection` |
| promote | `switch_primary_external_system` |
| demote | `demote_primary_external_system` |

Zusätzlich muss der Inhalt innerhalb des API-Scopes des Aufrufers liegen (die für die Rolle konfigurierten `api`-User-Filter), sonst antworten alle vier Endpunkte mit `401`. Übergangen wird davon nur die Gültigkeits-Komponente (`validity_period`, `in_validity_period` und ihre Negationen, auf jeder Verschachtelungsebene — auch innerhalb einer als Scope konfigurierten Sammlung) — auch ein abgelaufener Inhalt bleibt verknüpfbar.

Eingebettete Inhalte sind nicht ausgenommen: Importe vergeben auch an sie eigene externe Schlüssel, und im Backend lassen sich alle vier Aktionen auf ihnen ausführen. Zu beachten ist allerdings, dass ein konfigurierter API-Scope eingebettete Inhalte grundsätzlich nicht enthält — für einen Aufrufer mit Scope antworten die Endpunkte auf einen eingebetteten Inhalt daher mit `401`, genau wie `GET /api/v4/things/<THING-ID>` es tut.

Die Standard-Parameter der APIv4 (`language`, `include`, `fields`, `sort`, `page`, `section`) werden akzeptiert, wirken auf diese Endpunkte aber nicht: die Antwort ist immer der vollständige aktuelle Stand der Verknüpfungen des Inhaltes.

## Fehlerbehandlung

| Status | Bedeutung |
|---|---|
| `400` | `propertyID` oder `value` fehlt |
| `401` | keine Berechtigung für diese Aktion, Inhalt außerhalb des API-Scopes (bzw. nicht authentifiziert) |
| `404` | Inhalt oder externes System existiert nicht, oder `promote` adressiert eine nicht vorhandene Verknüpfung |
| `409` | `promote` zeigt auf einen externen Schlüssel, den bereits ein anderer Inhalt als Primärschlüssel verwendet |
| `422` | die adressierte Verknüpfung ist das Primärsystem (dafür ist `demote` vorgesehen), oder sie wird von einem Import bzw. Export verwaltet, oder `demote` wurde auf einem Inhalt ohne Primärsystem aufgerufen |

Fehler werden im Format der APIv4 ausgespielt:

```json
{
  "errors": [
    {
      "source": { "pointer": "/api/v4/things/<THING-ID>/external_connections" },
      "detail": "the addressed connection is the primary external system of this content, use the demote endpoint instead"
    }
  ]
}
```

Über die Datenschnittstelle werden ausschließlich Verknüpfungen vom Typ `duplicate` angelegt und entfernt. Verknüpfungen vom Typ `import` gehören dem Import, jene vom Typ `export` der Export-Maschinerie.
