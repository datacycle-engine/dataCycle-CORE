# GeoJSON

Das GeoJSON-Format eignet sich am besten dazu die Daten für eine weitere Prozessierung zu verwenden. Da es kein Paging gibt, kann die Dateigröße sehr anwachsen, was sich bei direkter Einbindung im Frontend nachteilig auf die Performance auswirken kann.

## Voraussetzungen

**Es muss eine Konfiguration hinterlegt werden, damit die Anfrage von Geodaten aktiviert ist.**

## Allgemeines

Anfragen von Daten im Format GeoJSON werden über die API v4 Schnittstelle durchgeführt. Dafür muss für die Anfrage der Header `Accept: application/geo+json` gesetzt werden.

Im Allgemeinen sind alle Filter der [allgemeinen Datenschnittstelle](/docs/api/contents) auch für die Ausgabe als GeoJSON anwendbar. In dieser Dokumentation werden drei Parameter hervorgehoben, mit denen man den den Inhalt der Attribute beeinflussen kann - `include`, `fields` und `classification_trees`.

Zur Authentifizierung muss das API-Token, als URL-Parameter, im JSON-Body oder als Bearer-Token im HTTP-Header mitgesendet werden.

**Zu beachten ist, dass eine implizite Filterung auf Geo-Objekte aktiv ist. Es werden keine Daten ohne Koordinaten ausgegeben.**

## Anfragen

Es können Einzelobjekte oder Ergebnisse von Suchen bzw. Inhaltssammlungen abgefragt werden. Dafür sind die Routen `/things/<THING-ID>` und `/endpoints/<ENDPOINT-ID>` vorgesehen. Folgend werden Beispiele für die Anfrage angeführt, wobei bei den Endpoints Beispiele für die Einschränkung der Attribute und Filterung angeführt werden.

Anfragen können als GET oder POST-Methoden gesendet werden.

### Einzelobjekte

Die Anfrage eines Einzelobjektes liefert ein GeoJSON mit einem Feature.

#### Anfrage

```bash
curl --request GET \
  --url https://<URL>/api/v4/things/<THING-ID> \
  --header 'Accept: application/geo+json' \
  --header 'Authorization: Bearer <TOKEN>'
```

#### Antwort

```json
{
  "type": "Feature",
  "id": "<THING-ID>",
  "geometry": {
    "type": "Point",
    "coordinates": [
      14.298621,
      46.607465
    ]
  },
  "properties": {
    "@id": "<THING-ID>",
    "@type": [
      "Place",
      "dcls:Örtlichkeit"
    ],
    "name": "dataCycle"
  }
}
```

### Endpoints

Endpoints beinhalten Elemente einer gespeicherten Suche oder Inhaltssammlung und liefern eine FeatureCollection mit den Inhalten.

#### Anfrage

```bash
curl --request POST \
  --url https://<URL>/api/v4/endpoints/<ENDPOINT-ID> \
  --header 'Accept: application/geo+json' \
  --header 'Authorization: Bearer <TOKEN>' \
  --header 'Content-Type: application/json' \
  --data '{
    "filter": {
        "search": "Rosentaler"
    }
}'
```

#### Antwort

```json
{
  "type": "FeatureCollection",
  "crs": {
    "type": "name",
    "properties": {
      "name": "urn:ogc:def:crs:EPSG::4326"
    }
  },
  "features": [
    {
      "type": "Feature",
      "id": "<THING-ID>",
      "geometry": {
        "type": "Point",
        "coordinates": [
          14.298621,
          46.607465
        ]
      },
      "properties": {
        "@id": "<THING-ID>",
        "@type": [
          "Place",
          "dcls:Örtlichkeit"
        ],
        "name": "dataCycle"
      }
    },
    {
      "type": "Feature",
      "id": "<THING-ID>",
      "geometry": {
        "type": "MultiLineString",
        "coordinates": [
          [
            [
              14.298621,
              46.607465
            ],
            [
              14.298379,
              46.607329
            ]
          ]
        ]
      },
      "properties": {
        "@id": "236bc505-af08-4e53-ae27-69809cd9fff7",
        "@type": [
          "Place",
          "dcls:Tour"
        ],
        "name": "Tour durchs Rosental"
      }
    }
  ]
}
```

#### Beeinflussung der Attribute

Die Attribute können mit folgenden Parameter beeinflusst werden:

- `include` - zeigt die Klassifizierungen des Objektes an

- `classification_trees` - schränkt die Klassifizierungen auf einen Klassifizierungsbaum ein

- `fields`  - schränkt die Ausgabe auf die angegebenen Felder ein

#### Anfrage

```bash
curl --request POST \
  --url https://<URL>/api/v4/endpoints/<ENDPOINT-ID> \
  --header 'Accept: application/geo+json' \
  --header 'Authorization: Bearer <TOKEN>' \
  --header 'Content-Type: application/json' \
  --data '{
    "include": "dc:classification",
    "classification_trees": "<CLASSIFICATION-TREE-ID>",
    "fields": "@id,dc:classification.@id",
    "filter": {
        "search": "Rosentaler"
    }
}'
```

#### Antwort

```json
{
  "type": "FeatureCollection",
  ...
  },
  "features": [
    {
      "type": "Feature",
      ...
      },
      "properties": {
        "@id": "<THING-ID>",
        "@type": [
          "Place",
          "dcls:Örtlichkeit"
        ],
        "dc:classification": [
          {
            "@id": "<CLASSIFICATION-ID>"
          },
          {
            "@id": "<CLASSIFICATION-ID>"
          },
        ]
      }
    },
    {
      ...
    }
  ]
}
```
