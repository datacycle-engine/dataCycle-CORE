## Voraussetungen

**Es muss eine Konfiguration hinterlegt werden, damit eingehende Webhooks aktiviert sind.**

In dieser Konfiguration wird auch das Format der eingehenden Daten definiert (z.B. JSON-LD).

Das allgemeine URL-Schema für eingehende Webhooks lautet: _**/api/v4/external_sources/CONFIGURATION_ID**_.

## Einschränkungen

Das Format der eingehenden Daten entspricht der Ausgabe der [APIv4](/docs/api).

**_Aktuell können nur einfache Attribute übergeben werden ('string', 'number', 'date', 'datetime', 'boolean')_**.

_Manche Attribute werden unter einem anderen Namen über die APIv4 ausgegeben, diese können ebenfalls noch nicht übergeben werden_.

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

#### HTTP-POST:

_/api/v4/external_sources/CONFIGURATION_ID_

entweder als JSON mit `asset[remote_file_url]`

```json
{
  "token": "YOUR_ACCESS_TOKEN",
  "@graph": [
    {
      "@type": "dcls:Bild",
      "name": "Bild 1",
      "caption": "Caption 1",
      "description": "Beschreibung 1",
      "asset": {
        "remote_file_url": "http://www.test.at/testbild.png"
      }
    }
  ]
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
