## Voraussetzungen

**Es muss eine Konfiguration hinterlegt werden, damit eingehende Webhooks aktiviert sind.**

In dieser Konfiguration wird auch das Format der eingehenden Daten definiert (z.B. JSON-LD).

Das allgemeine URL-Schema für eingehende Webhooks lautet: _**/api/v4/external_sources/CONFIGURATION_ID**_.

## Einschränkungen

Das Format der eingehenden Daten entspricht der Ausgabe der [APIv4](/docs/api).

**_Aktuell können nur noch nicht alle Attribute übergeben werden_**.

_Manche Attribute werden unter einem anderen Namen über die APIv4 ausgegeben; manche dieser können ebenfalls noch nicht übergeben werden_.

## Allgemein

Der Inhalt kann als JSON-Body, URL-Encoded Form oder Multipart Form übergeben werden.

`@type` kann entweder aus der APIv4 Ausgabe (der letzte @type eines Inhalts), oder vom entsprechenden [Schema](/schema) (hier ist es der Teil in Klammern) entnommen werden.

Beispiele:

JSON:

```json
{
  "token": "YOUR_ACCESS_TOKEN",
  "@graph": [
    {
      "@type": "dcls:Bild",
      "name": "Name des 1. Bildes"
    },
    {
      "@type": "dcls:Bild",
      "name": "Name des 2. Bildes"
    }
  ]
}
```

URL-Encoded oder Multipart Form:

```
| Name            | Value              |
| --------------- | ------------------ |
| token           | YOUR_ACCESS_TOKEN  |
| @graph[][@type] | dcls:Bild          |
| @graph[][name]  | Name des 1. Bildes |
| @graph[][@type] | dcls:Bild          |
| @graph[][name]  | Name des 2. Bildes |
```

## Übersetzungen

Es ist möglich die Sprache des zu erstellenden Inhaltes zu definieren:

```json
{
  "@context": {
    "@language": "de"
  }
}
```

```
| Name                | Value |
| ------------------- | ----- |
| @context[@language] | de    |
```

Es können nur jene Sprachen übergeben werden, die im System erlaubt sind.

Alternativ können auch Übersetzungen für bestimmte Attribute übergeben werden. Das funktioniert allerdings nur bei Attributen, die übersetzbar sind.

Übersetzbare Attribute sind beim jeweiligen [Schema](/schema) mit einem bestimmten Icon (<i class="fa fa-language has-tip" title="Translated"></i>) gekennzeichnet.

```json
{
  "@graph": [
    {
      "@type": "dcls:Bild",
      "name": [
        {
          "@language": "de",
          "@value": "Bild 1"
        },
        {
          "@language": "en",
          "@value": "Bild 1 englisch"
        }
      ]
    }
  ]
}
```

```
| Name                        | Value              |
| --------------------------- | ------------------ |
| @graph[][name][][@language] | de                 |
| @graph[][name][][@value]    | Name des Bildes    |
| @graph[][name][][@language] | en                 |
| @graph[][name][][@value]    | Name des Bildes en |
```

## Erstellen von Inhalten

Nun ist geklärt, wie man grundsätzlich Daten übergeben kann und wie Übersetzungen funktionieren. Hier ein paar Beispiel-Requests, wie man Inhalte erstellen kann.

**Hinweis zur `@id`**: Die `@id` eines Inhaltes wird als `external_key` gespeichert und kann später zum Aktualisieren oder Löschen des Inhaltes verwendet werden. Das Anlegen von Inhalten ohne `@id` ist ebenfalls möglich, in diesem Fall wird eine `@id` automatisch generiert. Wichtig ist jedoch zu beachten, dass intern immer eine eigene ID generiert wird, die in der API als `@id` zurückgegeben wird. Diese ID kann dann für Verlinkungen verwendet werden, nicht jedoch die `@id` aus dem Request.

_Beispiel 1: POI_

`POST \_/api/v4/external_sources/CONFIGURATION_ID`

```json
{
  "token": "YOUR_ACCESS_TOKEN",
  "@graph": [
    {
      "@id": "test-poi-1",
      "@type": "POI",
      "name": "Test POI",
      "address": {
        "@type": "PostalAddress",
        "url": "https://www.example.com",
        "email": "test@email.at",
        "telephone": "+43 123456789",
        "name": "First Last",
        "streetAddress": "Teststraße 1",
        "addressCountry": "Wakanda"
      },
      "geo": {
        "@type": "GeoCoordinates",
        "latitude": 14.1,
        "longitude": 14.2
      },
      "dc:additionalInformation": [
        {
          "@type": "Ergänzende Information",
          "name": "Kurzbeschreibung",
          "description": "Text"
        }
      ]
    }
  ],
  "@context": {
    "@language": "de"
  }
}
```

_Beispiel 2: Veranstaltung_

**Hinweis:** `eventSchedule` ist ein Array aus [schema.org `Schedule`-Typen](https://schema.org/Schedule).

```json
{
  "@graph": [
    {
      "@type": "Event",
      "@id": "test-event-1",
      "name": "Test-Event 1",
      "eventSchedule": [
        // Einmalig am 01.06.2024 von 12:00 bis 14:00 Uhr
        {
          "@type": "Schedule",
          "startDate": "2024-06-01",
          "startTime": "12:00",
          "scheduleTimezone": "Europe/Vienna",
          "endTime": "14:00"
        },
        // Wöchentlich am Dienstag und Donnerstag zwischen 12:00 und 14:00 Uhr von 01.06.2024 bis 31.12.2024
        {
          "@type": "Schedule",
          "startDate": "2024-06-01",
          "startTime": "12:00",
          "scheduleTimezone": "Europe/Vienna",
          "endTime": "14:00",
          "byDay": ["https://schema.org/Tuesday", "https://schema.org/Thursday"],
          "endDate": "2024-12-31",
          "repeatFrequency": "P1W"
        },
        // Monatlich am 3. Sonntag zwischen 15:00 und 16:00 Uhr von 16.07.2024 bis 20.08.2024
        {
          "@type": "Schedule",
          "scheduleTimezone": "Europe/Vienna",
          "startDate": "2024-07-16",
          "endDate": "2024-08-20",
          "startTime": "15:00",
          "endTime": "16:00",
          "byDay": "https://schema.org/Sunday",
          "repeatFrequency": "P1M",
          "byMonthWeek": 3
        }
      ]
    }
  ],
  "@context": {
    "@language": "de"
  }
}
```

_Beispiel 3: Bild_

`POST _/api/v4/external_sources/CONFIGURATION_ID`

entweder als JSON mit `asset[remote_file_url]`, wobei `remote_file_url` eine öffentlich erreichbare URL ist, oder mit `asset[base64_file_blob]`, wobei `base64_file_blob` ein Base64-kodierter String ist.
Im Falle von `base64_file_blob` ist auch der Name der Datei verpflichtend.

```json
{
  "token": "YOUR_ACCESS_TOKEN",
  "@graph": [
    {
      "@type": "dcls:Bild",
      "name": "Bild 1",
      "caption": "Caption 1",
      "asset": {
        "remote_file_url": "http://www.example.com/image.jpg",
        "name": "image.jpg" // optional
      }
    },
    {
      "@type": "dcls:Bild",
      "name": "Bild 2",
      "caption": "Caption 2",
      "asset": {
        "base64_file_blob": "iVBORw0KGgoAAAANSUhEUgAAAAgAAAAIAQMAAAD+wSzIAAAABlBMVEX///+/v7+jQ3Y5AAAADklEQVQI12P4AIX8EAgALgAD/aNpbtEAAAAASUVORK5CYII",
        "name": "image.jpg" // verpflichtend
      }
    }
  ],
  "@context": {
    "@language": "de"
  }
}
```

oder als Multipart Form mit `asset[file]`

```
| Name                  | Value              |
| --------------------- | ------------------ |
| token                 | YOUR_ACCESS_TOKEN  |
| @graph[][@type]       | dcls:Bild          |
| @graph[][name]        | Name des Bildes    |
| @graph[][asset][file] | Bilddatei          |

```

### Verlinkungen

Inhalte können auch miteinander verlinkt werden. Über diese Schnittstelle ist es möglich, bereits bestehende Inhalte anhand ihrer dataCycle ID zu verknüpfen, oder die verknüften Inhalte direkt zu erstellen.

_Beispiel 1: Verlinkung von vorhandenen Inhalten_

Angenommen, es gibt bereits Bilder mit den IDs `8adfb8e0-0f8c-4953-9682-04541d389837` und `effa3d05-dfb0-4943-946f-8bfd4d1d259b`, und einen Ort mit der ID `f94ab9c9-436a-4194-9e60-e10f5f400325`.
Grundsätzlich erfolgt die Verlinkung und Angabe der ID des Inhalts sowie dessen Typ.

```json
{
  "@id": "ID_DES_INHALTES",
  "@type": "TYP_DES_INHALTES"
}
```

**Achtung**: Werden weitere Felder angegeben, wird versucht, einen neuen Inhalt zu erstellen oder einen bestehenden Inhalt zu aktualisieren.

```json
{
  "@graph": [
    {
      "@type": "Event",
      "@id": "test-event-1",
      "name": "Test-Event 1",
      "image": [
        {
          "@id": "8adfb8e0-0f8c-4953-9682-04541d389837",
          "@type": "dcls:Bild"
        },
        {
          "@id": "effa3d05-dfb0-4943-946f-8bfd4d1d259b",
          "@type": "dcls:Bild"
        }
      ],
      "location": [
        {
          "@id": "f94ab9c9-436a-4194-9e60-e10f5f400325",
          "@type": "POI"
        }
      ]
    }
  ],
  "@context": {
    "@language": "de"
  }
}
```

Kennt man die interne ID des Inhaltes, kann man auch diese kompaktere Schreibweise verwenden. Dies funktioniert aber **nur** für die interne ID.

```json
{
  "@graph": [
    {
      "@type": "Event",
      "@id": "test-event-1",
      "name": "Test-Event 1",
      "image": ["8adfb8e0-0f8c-4953-9682-04541d389837", "effa3d05-dfb0-4943-946f-8bfd4d1d259b"],
      "location": ["f94ab9c9-436a-4194-9e60-e10f5f400325"]
    }
  ],
  "@context": {
    "@language": "de"
  }
}
```

_Beispiel 2: Verlinkung von neuen Inhalten_

```json
{
  "@graph": [
    {
      "@type": "Event",
      "@id": "test-event-1",
      "name": "Test-Event 1",
      "image": [
        {
          "@id": "mein-bild-1",
          "@type": "dcls:Bild",
          "name": "Bild 1",
          "caption": "Caption 1",
          "asset": {
            "remote_file_url": "https://picsum.photos/200/300"
          },
          "copyrightHolder": [
            {
              "@id": "copyright-holder-1",
              "@type": "Person",
              "givenName": "First",
              "familyName": "Last"
            }
          ],
          "author": [
            {
              "@id": "author-1",
              "@type": "Organization",
              "name": "Organization Name"
            }
          ]
        },
        {
          "@id": "mein-bild-2",
          "@type": "dcls:Bild",
          "name": "Bild 2",
          "caption": "Caption 2",
          "asset": {
            "base64_file_blob": "iVBORw0KGgoAAAANSUhEUgAAAAgAAAAIAQMAAAD+wSzIAAAABlBMVEX///+/v7+jQ3Y5AAAADklEQVQI12P4AIX8EAgALgAD/aNpbtEAAAAASUVORK5CYII",
            "name": "image.jpg"
          }
        }
      ],
      "location": [
        {
          "@id": "mein-poi-1",
          "@type": "POI",
          "name": "Test POI",
          "address": {
            "@type": "PostalAddress",
            "url": "https://www.example.com",
            "email": "email@example.org"
          }
        }
      ]
    }
  ],
  "@context": {
    "@language": "de"
  }
}
```

In diesem Beispiel werden zwei neue Bilder und ein neuer Ort erstellt und mit der Veranstaltung verlinkt. Beim ersten Bild werden auch der Autor und der Rechteinhaber erstellt und verlinkt.

_Beispiel 3: Verlinkung von neuen und vorhandenen Inhalten_

Eine Kombination von neuen und vorhandenen Inhalten ist ebenfalls möglich. Im folgenden Beispiel wird ein neues Bild und ein bereits vorhandenes Bild verknüpft.

```json
{
  "@graph": [
    {
      "@type": "Event",
      "@id": "test-event-1",
      "name": "Test-Event 1",
      "image": [
        {
          "@id": "mein-bild-1",
          "@type": "dcls:Bild"
        },
        {
          "@type": "dcls:Bild",
          "name": "Bild 2",
          "caption": "Caption 2",
          "asset": {
            "remote_file_url": "https://picsum.photos/200/300"
          }
        }
      ]
    }
  ],
  "@context": {
    "@language": "de"
  }
}
```

## Update von Inhalten

Inhalte können auch aktualisiert werden. Dazu kann entweder die dataCycle ID oder die externe ID verwendet werden.

Das Aktualisieren von Inhalten funktioniert genauso wie das Erstellen von Inhalten, nur dass die `@id` des Inhaltes übergeben werden muss. Zur Verfügung stehen die HTTP-Methoden PUT und POST, wobei es **keinen** Unterschied gibt, welcher verwendet wird.

**Hinweis:** Es ist nicht möglich, die `@type` eines Inhaltes zu ändern.

_Beispiel 1: POI_

Wir ersetzen im folgenden Beispiel den Namen des POIs mit der ID `test-poi-1`. Zuerst erstellen wir einen Inhalt und danach aktualisieren wir ihn.

```json
{
  "@graph": [
    {
      "@id": "test-poi-1",
      "@type": "POI",
      "name": "Test POI",
      "address": {
        "@type": "PostalAddress",
        "url": "https://www.example.com",
        "email": "email@example.org"
      },
      "image": ["8adfb8e0-0f8c-4953-9682-04541d389837", "effa3d05-dfb0-4943-946f-8bfd4d1d259b"]
    }
  ],
  "@context": {
    "@language": "de"
  }
}
```

dataCycle erstellt den Inhalt und die dataCycle ID des Inhaltes ist angenommen `fc7dc35a-a8a2-412c-b545-9342b1e3d38e`.

Nun möchten wir den Namen ändern, die Addresse erweitern und ein verlinktes Bild entfernen. Wir können das entweder über unsere ID `test-poi-1` oder über die dataCycle ID `fc7dc35a-a8a2-412c-b545-9342b1e3d38e` machen.

**Hinweis:** Grundsätzlich gilt, dass Attribute, die nicht übergeben werden, unverändert bleiben.

`POST \_/api/v4/external_sources/CONFIGURATION_ID` oder `PUT /api/v4/external_sources/CONFIGURATION_ID`

```json
{
  "@graph": [
    {
      "@id": "test-poi-1", // oder "@id": "fc7dc35a-a8a2-412c-b545-9342b1e3d38e",
      "@type": "POI",
      "name": "Neuer Name",
      "address": {
        "@type": "PostalAddress",
        "url": "https://www.example.com",
        "email": "email@example.org",
        "telephone": "+43 123456789",
        "name": "First Last",
        "streetAddress": "Teststraße 1",
        "addressCountry": "Wakanda"
      },
      "image": ["8adfb8e0-0f8c-4953-9682-04541d389837"]
    }
  ],
  "@context": {
    "@language": "de"
  }
}
```

**Hinweis:** Das Bild mit der ID `effa3d05-dfb0-4943-946f-8bfd4d1d259b` wird nur aus der Verlinkung entfernt, nicht gelöscht.

_Beispiel 2: Verlinkte Inhalte_

Verlinkte Inhalte können entweder als in einem seperaten Request aktualisiert werden, oder direkt als verlinkte Inhalte im selben Request.

Hier erstellen wir eine Veranstaltung und wollen den obigen POI verlinken und gleichzeitig das Attribut `name` ändern.

```json
{
  "@graph": [
    {
      "@id": "test-event-1",
      "@type": "Event",
      "name": "Neuer Name",
      "location": [
        {
          "@id": "fc7dc35a-a8a2-412c-b545-9342b1e3d38e",
          "@type": "POI",
          "name": "Test POI updated linked"
        }
      ]
    }
  ],
  "@context": {
    "@language": "de"
  }
}
```

_Beispiel 3: Löschen von Attributen_

Um ein Attribut zu löschen, muss man es auf `null` oder ein leeres Array (falls ein Array zur Erstellung verwendet wird) setzen. Das Nicht-Übergeben eines Attributs wird als keine Änderung interpretiert. Pflichtfelder können nicht gelöscht werden, z.B. `name`.

```json
{
  "@graph": [
    {
      "@id": "fc7dc35a-a8a2-412c-b545-9342b1e3d38e",
      "@type": "POI",
      "name": "Test POI",
      "address": null,
      "image": null // oder []
    }
  ],
  "@context": {
    "@language": "de"
  }
}
```

## API Response und Fehlerbehandlung

Das Response Objekt ist folgend aufgebaut:

```json
[
  {
    "success": "Boolean|'partial'",
    "meta": {
      "thing_id": "UUID", // dataCycle ID des erstellten Inhaltes
      "external_key": "String", // externe ID des erstellten Inhaltes
      "language": "Array", // Array der Sprachen, in denen der Inhalt existiert
      "link": "String", // Link zum erstellten Inhalt in dataCycle
      "created": "Array", // Array der erstellten Inhalte
      "updated": "Array" // Array der aktualisierten Inhalte
    },
    "error": "Array", // Array der Fehlermeldungen
    "warnings": "Array" // Array der Warnungen
  }
]
```

Das `success`-Attribut gibt an, ob die Anfrage erfolgreich war. Bei teilweisem Erfolg wird der Wert `'partial'` zurückgegeben. Teilweiser Erfolg bedeutet, dass einige Inhalte erfolgreich erstellt oder aktualisiert wurden, während andere fehlschlugen.

Das `meta`-Attribut enthält unter anderem auch wichtige Informationen zu den erstellten oder aktualisierten Inhalten. Im `created`- und `updated`-Array sind Informationen zu den erstellten bzw. aktualisierten Inhalten enthalten. Diese sind folgendermaßen aufgebaut:

```json
{
  "thing_id": "UUID",
  "template": "String",
  "external_key": "String",
  "key?": "String", // Attributname
  "path": "Array" // Gibt an, wo im Request Object sich der Inhalt befindet, z.B. ["location"] oder ["image", "copyrightHolder"]
}
```

Hiermit kann geprüft werden, ob und welche Inhalte erfolgreich erstellt oder aktualisiert wurden.

Das `error`-Attribut speichert Fehler, die während der Bearbeitung aufgetreten sind, während das `warnings`-Attribut Warnungen auflistet, die nicht die erfolgreiche Verarbeitung verhindert haben. Jeder Eintrag in diesen Listen bietet eine detaillierte Beschreibung des jeweiligen Problems sowie einen Pfad, der hilft, den Ursprung des Fehlers oder der Warnung genau zu lokalisieren.

```json
{
  "message": "String",
  "path": "Array",
  "template?": "String" // Template des Inhaltes, falls anwendbar
}
```

## Löschen von Inhalten

Inhalte können auch gelöscht werden. Dazu kann entweder die dataCycle ID oder die externe ID verwendet werden.

`DELETE \_/api/v4/external_sources/CONFIGURATION_ID`

```json
{
  "@graph": [
    {
      "@id": "test-poi-1"
    }
  ]
}
```

**Hinweis:** Verlinkte Inhalte und embedded Inhalte werden ebenfalls gelöscht, sofern sie nicht in anderen Inhalten referenziert sind.

## Klassifizierungen

Klassifizierungen können ebenfalls gesetzt werden. Dafür muss unterschieden werden, ob die Klassifizierung als eigenes Attribute gesetzt wird, oder als "universal classifications". Infos dazu finden man beim jeweiligen [Schema](/schema).

Klassifizierungen müssen immer mit `dc:classification:` geprefixed werden. Um eine Klassifizierung zu setzen, benötigt man auch deren ID. Diese kann man in der [Klassifizierungsübersicht](/classifications) finden. Details zu Schnittstellen für Klassifizierungen finden sich in der [Klassifizierungs-API](/docs/api/classifications).

Angenommen wir wollen bei einem POI eine Klassifizierung für den Tag (tags - eigenes Attribut) und eine für den Ausgabekanal (universal classifications) setzen.

```json
{
  "@graph": [
    {
      "@id": "test-poi-1",
      "@type": "POI",
      "name": "Test POI",
      "dc:classification:tags": ["0741a837-4be6-4c75-85b5-9e00c614cc3e"],
      "dc:classification:universalClassifications": ["38903994-48c1-48bc-a2fc-6c956cd2b907"]
    }
  ],
  "@context": {
    "@language": "de"
  }
}
```

Löschen von Klassifizierungen funktioniert genauso wie das Löschen von Attributen. Um eine Klassifizierung zu löschen, entweder auf `null` setzen oder im Array nicht übergeben (falls man mehrere Klassifizierungen hat und nur eine Teilmenge löschen möchte).

```json
{
  "@graph": [
    {
      "@id": "test-poi-1",
      "@type": "POI",
      "name": "Test POI",
      "dc:classification:tags": null, // oder []
      "dc:classification:universalClassifications": ["f3d992c7-6a94-4b9b-b5e0-37627c9274db"] // die vorherige Klassifizierung wird gelöscht, diese hinzugefügt
    }
  ],
  "@context": {
    "@language": "de"
  }
}
```
