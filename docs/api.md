# Datenschnittstelle

Der Zugriff zu in dataCycle gespeicherte Daten erfolgt immer über eine gespeicherte Suche. Grund dafür ist, dass Inhalte dadurch auch im Nachhinein noch jederzeit eingeschränkt werden können. Dazu muss lediglich die gespeicherte Suche entsprechend angepasst werden.


## Authentifizierung

Die Authentifizierung erfolgt über ein sogenanntes _Authentifzierungs-Token_, dass beim Aufruf eines Daten-Endpunktes mit übergeben werden muss. Ist ein Benutzer bereits über das Frontend eingeloggt, kann das Token weggelassen werden, da in diesem Fall bereits eine aktive Session existiert und diese auch für die API weiter verwendet werden kann. Eine Übersicht über alle in einem System vorhandenen Klassifizierungbäume erhält man beispielsweise über [/api/v2/classification_trees?token=MY_TOKEN](/api/v2/classification_trees).


## Paging

Viele Endpunkte der Datenschnittstelle liefern eine größere Anzahl an Datensätzen aus. Um diese Daten trotzdem mit schnellen Antwortzeiten ausliefern zu können, greift dataCycle auf einen Paging-Mechanismus zurück und liefert große Datenmengen damit quasi häppchenweise aus. Die Parametrisierung des Pagings folgt dabei den Empfehlungen von [JSON API](http://jsonapi.org/format/#fetching-pagination) und erfolgt über die folgenden, optionalen Parameter:

* **page[size]**: Seitengröße / Anzahl der Datensätze pro ausgelieferter Seite
* **page[number]**: Seitenzahl

Um die Handundhabung des Pagings zu erleichtern, gibt es einige zusätzliche Attribute, damit z.B. die Gesamtanzahl der verfügbaren Datensätze auf jeder Seite zur Verfügung steht.

```javascript
// /api/v2/classification_trees

{
  data: {
    // ...
  }, meta: {
    total: 100
  }, links: {
    first: '/api/v2/classification_trees?page[size]=10&page[number]=1',
    prev: '/api/v2/classification_trees?page[size]=10&page[number]=3',
    self: '/api/v2/classification_trees?page[size]=10&page[number]=4',
    next: '/api/v2/classification_trees?page[size]=10&page[number]=5',
    last: '/api/v2/classification_trees?page[size]=10&page[number]=10'
  }
}
```

Die Gesamtanzahl wird innerhalb des ```meta```-Attributs mit dem Namen ```total``` ausgeliefert. Zusätzlich dazu werden Links zu den nächsten bzw. vorigen Seiten innerhalb des ```links```-Attributs ausgeliefert. Im Detail stehen folgende Informationen zur Verfügung:

* **first**: Link zur ersten Seite
* **prev**: Link zur vorigen Seite
* **self**: Link zur aktuellen Seite (inkl. der Standard-Werte der optionalen Parameter)
* **next**: Link zur nächsten Seite
* **last**: Link zur letzten Seite

