# Datenschnittstelle für Höhenprofile

In dataCycle gibt es die Möglichkeit, ein Höhenprofil für Routen abzurufen. Das funktioniert nur für Routen, bei denen Höheninformationen hinterlegt sind.

#### HTTP-GET:

_/api/v4/endpoints/<endpoint-id>/<thing-id>/elevation_profile?token=YOUR_ACCESS_TOKEN&dataFormat=object

#### HTTP-POST:

_/api/v4/endpoints/<endpoint-id>/<thing-id>/elevation_profile

```json
{
  "token": "YOUR_ACCESS_TOKEN",
  "dataFormat": "object" // "array" oder "object"
}
```

### Rückgabewert

Der Rückgabewert hat folgendes Schema, je nachdem welches "dataFormat" angefragt wurde.

#### dataFormat object (default):
```json
{
  "data": [
    {
      x: 0, // Abstand zum Startpunkt in Metern
      y: 568, // Höhe über dem Meeresspiegel in Metern
      coordinates: [9.802584, 47.150712]
    },
    {
      x: 6.3,
      y: 576,
      coordinates: [9.802617, 47.15066]
    },
    {
      x: 13.12,
      y: 586,
      coordinates: [9.802537, 47.150632]
    }
  ],
  "meta": {
    "scaleX": "m",
    "scaleY": "m",
  }
}
```

#### dataFormat array:
```json
{
  "data": [
    [
      0, // Abstand zum Startpunkt in Metern
      568, // Höhe über dem Meeresspiegel in Metern
      [9.802584, 47.150712]
    ],
    [
      6.3,
      576,
      [9.802617, 47.15066]
    ],
    [
      13.12,
      586,
      [9.802537, 47.150632]
    ]
  ],
  "meta": {
    "scaleX": "m",
    "scaleY": "m",
  }
}
```

#### Fehler

Bei einer fehlerhaften Anfrage oder Inhalten ohne Höheninformationen wird ein entsprechender HTTP-Status geschickt, der optional auch einen JSON-Body enhält.

```json
{
  "error": "no elevation data found for ..."
}
```
