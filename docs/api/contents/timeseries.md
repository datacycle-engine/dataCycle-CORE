# Datenschnittstelle für Zeitserien

In dataCycle gibt es die Möglichkeit, die Werte einer Zeitserie abzurufen. Die URL wird über die APIv4 unter dem entsprechenden Attribut für die Zeitserie ausgespielt

#### HTTP-GET:

```url
_/api/v4/things/<THING-ID>/<ATTRIBUT>?token=<YOUR_ACCESS_TOKEN>
```
#### HTTP-POST:

```url
_/api/v4/things/<THING-ID>/<ATTRIBUT>
```
JSON-Body:
```json
{
  "token": "YOUR_ACCESS_TOKEN",
  "dataFormat": "object",
  "groupBy": "avg_hour",
  "time": {
    "in": {
      "min": "2023-07-20T09:00:00+02:00",
      "max": "2023-07-20T10:00:00+02:00"
    }
  }
}
```

### Rückgabewert

Der Rückgabewert hat folgendes Schema, je nachdem welches "dataFormat" angefragt wurde.

#### dataFormat array (default):
```json
{
  "data": [
    [
      "2023-07-20T09:00:00+02:00",
      568
    ],
    [
      "2023-07-20T09:00:01+02:00",
      576
    ],
    [
      "2023-07-20T09:00:02+02:00",
      586
    ]
  ]
}
```

#### dataFormat object:
```json
{
  "data": [
    {
      x: "2023-07-20T09:00:00+02:00",
      y: 568
    },
    {
      x: "2023-07-20T09:00:01+02:00",
      y: 576
    },
    {
      x: "2023-07-20T09:00:02+02:00",
      y: 586
    }
  ]
}
```

### Parameter

##### ```dataFormat``` (default: "array")
Es gibt aktuell zwei Formate, siehe Beispiele.

* "array"
* "object"

##### ```groupBy```
Gruppierung der Ergebnisse.
Hier kann eine Kombination aus Aggregatfunktion und Gruppierungsfunktion übergeben werden.

***Aggregatfunktion***: "sum", "min", "max", "avg"
***Gruppierungsfunktionen***: "hour", "day", "week", "month", "quarter", "year"

Beispiel: "sum_day"

##### ```time[in][min]``` (ISO 8601 String)
Einschränkung der Ergebnisse auf ein Startdatum

##### ```time[in][max]``` (ISO 8601 String)
Einschränkung der Ergebnisse auf ein Enddatum
