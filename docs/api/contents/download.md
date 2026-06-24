# Herunterladen von Inhalten über die Datenschnittstelle

Inhalte können über die Datenschnittstelle nicht nur als [JSON-LD](/docs/api/contents) abgefragt, sondern auch in unterschiedlichen Formaten (z.B. **GPX**) als Datei heruntergeladen werden. Welches Format ausgeliefert wird, steuert der Parameter `serializeFormat`.

Ein typischer Anwendungsfall ist der Download von Touren oder Orten als **GPX**-Datei, die anschließend z.B. in ein Navigationsgerät oder eine Wander-App importiert werden kann.

## Voraussetzungen

**Der Download muss für die jeweilige dataCycle-Instanz konfiguriert und aktiviert sein.** Welche Formate (Serializer) zur Verfügung stehen, wird pro Instanz und pro Inhaltsart festgelegt. Ist ein Format für die angefragten Inhalte nicht freigeschaltet, antwortet die Datenschnittstelle mit einem Fehler (siehe [Fehler](#fehler)).

## Allgemeines

Zur Authentifizierung empfiehlt sich die Verwendung eines API-Token, es können aber prinzipiell alle für die Datenschnittstelle angebotenen [Authentifizierungs-Mechanismen](/docs/api#authentifizierung) genutzt werden.

Die Anfragen können sowohl über **HTTP-GET** als auch über **HTTP-POST** durchgeführt werden. Bei einer POST-Abfrage werden die Parameter im **JSON**-Format übermittelt.

Im Gegensatz zu den übrigen Endpunkten der Datenschnittstelle liefert der Download nicht JSON-LD, sondern die serialisierte Datei direkt im jeweiligen Format aus (z.B. `application/gpx+xml`). Die Antwort wird mit dem Header `Content-Disposition: attachment` als Datei-Download ausgeliefert.

## Parameter

##### `serializeFormat` (required: true)

Legt das Ausgabeformat fest. Welche Werte unterstützt werden, hängt von der Konfiguration der jeweiligen dataCycle-Instanz und der angefragten Inhaltsart ab. Häufig verfügbare Formate sind:

* `gpx` – Geodaten im [GPX](https://www.topografix.com/gpx.asp)-Format (`application/gpx+xml`)
* `json` – Inhalt als JSON
* `xml` – Inhalt als XML

## Herunterladen eines einzelnen Inhalts

Ein einzelner Inhalt wird über die ID des Datenendpunkts (`ENDPOINT-ID`) und die ID des Inhalts (`THING-ID`) angesprochen. Der Inhalt muss dabei über den angegebenen Datenendpunkt erreichbar sein.

#### HTTP-GET:

```url
/api/v4/endpoints/<ENDPOINT-ID>/<THING-ID>/download?token=<YOUR_ACCESS_TOKEN>&serializeFormat=gpx
```

#### HTTP-POST:

```url
/api/v4/endpoints/<ENDPOINT-ID>/<THING-ID>/download
```

JSON-Body:

```json
{
  "token": "YOUR_ACCESS_TOKEN",
  "serializeFormat": "gpx"
}
```

## Herunterladen einer ganzen Inhaltssammlung

Es kann auch der gesamte Inhalt eines Datenendpunkts (statische oder dynamische Inhaltssammlung) in einer einzigen Datei heruntergeladen werden. Dafür wird die `THING-ID` weggelassen. Alle [Filter](/docs/api/contents#filtern-von-inhalten) der allgemeinen Datenschnittstelle können dabei zusätzlich angewendet werden, um die ausgelieferten Inhalte einzuschränken.

#### HTTP-GET:

```url
/api/v4/endpoints/<ENDPOINT-ID>/download?token=<YOUR_ACCESS_TOKEN>&serializeFormat=gpx
```

#### HTTP-POST:

```url
/api/v4/endpoints/<ENDPOINT-ID>/download
```

JSON-Body:

```json
{
  "token": "YOUR_ACCESS_TOKEN",
  "serializeFormat": "gpx",
  "filter": {
    "q": "Wanderung"
  }
}
```

## Rückgabewert

Die Antwort ist die serialisierte Datei im angeforderten Format und wird als Datei-Download ausgeliefert. Eine GPX-Datei für eine Tour hat z.B. folgende Struktur:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="dataCycle" xmlns="http://www.topografix.com/GPX/1/1">
  <metadata>
    <name>Tour durchs Rosental</name>
    <desc>...</desc>
    <link href="https://<URL>/api/v4/universal/<THING-ID>"/>
    <time>2024-01-01T00:00:00Z</time>
  </metadata>
  <trk>
    <name>Route</name>
    <trkseg>
      <trkpt lat="46.607465" lon="14.298621">
        <ele>568</ele>
      </trkpt>
      <trkpt lat="46.607329" lon="14.298379">
        <ele>576</ele>
      </trkpt>
    </trkseg>
  </trk>
</gpx>
```

Punkt-Geometrien (z.B. Orte) werden als Wegpunkte (`wpt`), Linien-Geometrien (z.B. Touren) als Tracks (`trk`/`trkseg`/`trkpt`) ausgegeben. Sind Höheninformationen vorhanden, werden diese als `ele` ergänzt.

## Fehler

Ist das angeforderte Format für die Inhalte nicht freigeschaltet oder ungültig, antwortet die Datenschnittstelle mit dem HTTP-Status `400 Bad Request` und folgendem JSON-Body:

```json
{
  "errors": [
    {
      "title": "The selected download method is not supported"
    }
  ]
}
```

Ist der angegebene Datenendpunkt oder der Inhalt nicht (über diesen Endpunkt) erreichbar, wird mit `404 Not Found` geantwortet.
