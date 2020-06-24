[//]: # "# Datenschnittstelle"

## Klassifizierungen

Eine der wesentlichen Funktionalitäten von dataCycle ist das Klassifizieren von Inhalten sowohl für in dataCycle nativ erstellte Inhalte als auch für importierte Inhalte von externen Systemen. Da sich die so entstehendenden Klassifizierungsbäume laufend ändern können, weil z.B. die Klassifizierungssystematik eines externen Systems angepasst wird oder weil Benutzer neue Klassifizierungsbäume über Klassifizierungsmappings aufbauen, wird empfohlen, Klassifizierungen regelmäßig über die entsprechende Datenschnittstelle abzurufen, um auf Änderungen zeitnahe reagieren zu können. Ausgangspunkt für die Datenschnittstelle sind die in dataCycle verfügbaren Klassifizierungsbäume. Die unterschiedlichen Bäume können dabei über die URL [/api/v2/classification_trees?token=MY_TOKEN](/api/v2/classification_trees) abgerufe werden. Dieser Endpunkt liefert die ID, den Namen und die URL zu den Details für den jeweiligen Klassifizierungsbaum:

```javascript
// /api/v2/classification_trees

{
  data: [
    {
      "id":"26a95e72-96b9-4c27-b82b-244b5f51fcba",
      "name":"Inhaltstypen",
      "url":"http://localhost:3000/api/v2/classification_trees/26a95e72-96b9-4c27-b82b-244b5f51fcba"
    }, {
      "id":"09436f88-78b5-4812-9134-cf2b226fc067",
      "name":"Geschlecht",
      "url":"http://localhost:3000/api/v2/classification_trees/09436f88-78b5-4812-9134-cf2b226fc067"
    }, {
      "id":"32e0f52b-82b1-4a9b-9c98-b16f040a48c8",
      "name":"Wochentage",
      "url":"http://localhost:3000/api/v2/classification_trees/32e0f52b-82b1-4a9b-9c98-b16f040a48c8"
    }
  ], meta: {
    total: 3
  }, links: {
    self: '/api/v2/classification_trees?page[size]=25&page[number]=1'
  }
}
```

Über die mitgelieferte URL kann die Detailseite einer einzelnen Klassifzierung abgerufen werden. Diese wiederum beinhaltet über das Attribute ```classifications``` einen Verweis auf die eigentlichen Klassifzierungen:

```javascript
// /api/v2/classification_trees/09436f88-78b5-4812-9134-cf2b226fc067/classifications

{
  "data": [
    {
      "id": "efc5b184-cbff-41c5-8053-bb806a0a8f5c",
      "name": "Männlich",
      "createdAt": "2018-10-01T13:01:57.030+02:00",
      "updatedAt": "2018-10-01T13:01:57.030+02:00",
      "ancestors": [
        {
          "id": "09436f88-78b5-4812-9134-cf2b226fc067",
          "name": "Geschlecht",
          "createdAt": "2018-10-01T13:01:57.025+02:00",
          "updatedAt": "2018-10-01T13:01:57.025+02:00"
        }
      ]
    }, {
      "id": "bba6a087-8150-4f1c-91fc-4611843c2680",
      "name": "Weiblich",
      "createdAt": "2018-10-01T13:01:57.047+02:00",
      "updatedAt": "2018-10-01T13:01:57.047+02:00",
      "ancestors": [
          {
          "id": "09436f88-78b5-4812-9134-cf2b226fc067",
          "name": "Geschlecht",
          "createdAt": "2018-10-01T13:01:57.025+02:00",
          "updatedAt": "2018-10-01T13:01:57.025+02:00"
        }
      ]
    }
  ],
  "meta": {
    "total": 2
  },
  "links": {
    "self": "/api/v2/classification_trees/09436f88-78b5-4812-9134-cf2b226fc067/classifications?page[number]=1&page[size]=25"
  }
}
```

Das Resultat dieser Abfrage beinhaltet neben den Klassifizierungen selbst noch zusätzliche Daten zu den einzelnen Kategorien, wie das Erstellungs- und das letzte Änderungsdatum aber auch den vollständigen Pfad der Klassifizierung im Baum. Mit diesen Informationen kann der komplette Klassifizierungsbaum in einem externen System vollständig nachgebildet werden.

Die Endpunkte für Klassifizierungen und Klassifizierungsbäume unterstützen bei der Abfrage von Daten sowohl den unter [Dokumentation > Datenschnittstelle](/docs/api) beschriebenen Mechanismus für das Paging als auch die Abfrage von Änderungen.
