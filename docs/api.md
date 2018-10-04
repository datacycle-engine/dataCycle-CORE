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


## Verknüpfte Inhalte

Die Datenstruktur innerhalb von dataCycle ist grundsätzlich so aufgebaut, dass ein Inhalt mit beliebig vielen anderen Inhalten verknüpft werden kann. Ein POI beispielsweise hat in der Regel mehrere Bilder, die mit ihm verknüpft sind. Damit diese Verknüpfungen direkt beim Abruf der Daten aufgelöst werden und nicht im Nachhinein manuell aufgelöst werden müssen, steht der Query-Parameter ```include=linked``` zur Verfügung. Dieser Parameter kann sowohl beim Abruf eines einzelnen Datensatzes als auch beim Abruf von mehreren Datensätzen über einen API-Endpunkt genutzt werden.

**ACHTUNG: Der Parameter _include=linked_ kann sich spürbar auf die Performance der Datenschnittstelle auswirken, da unter Umständen eine sehr große Menge an zusätzlichen Daten ausgeliefert werden muss.**


## Aktualisierungen

Für einige Anwendungsfälle kann es notwendig sein, herauszufinden, welche Datensätze innerhalb einer vorgegeben Zeitspanne geändert worden sind. Zu diesem Zweck können bei API-Endpunkten, über die mehrere Inhalte auf der gleichen Ebene ausgeliefert werden, also grundsätzliche alle Endpunkte, die auch Paging unterstützen, zusätzliche Filter-Parameter genutzt werden. Dadurch kann die Anzahl der Datensätze, die geladen werden müssen, erheblich reduziert werden. Außerdem muss die Prüfung, ob es seit dem letzten Update neue Änderungen gegeben hat, nicht client-seitig durchgeführt werden, wodurch die Client-Anwendung noch einmal deutlich entlastet werden kann. Die Filter die für diesen Mechanismus genutzt werden können sehen folgendermaßen aus:

* **filter[created_since]**: Es werden nur Datensätzen ausgeliefert, die seit dem übergebenen Zeitpunkt erstellt worden sind
* **filter[modified_since]**: Es werden nur Datensätzen ausgeliefert, die sich seit dem übergebenen Zeitpunkt geändert haben

Der Zeitpunkt muss dabei entsprechend den Vorgaben von [RFC 3339](https://tools.ietf.org/html/rfc3339) übergeben werden. Eine Anfrage könnte beispielsweise folgendermaßen aussehen: [/api/v2/classification_trees?filter[created_since]=2018-03-28T23:57](/api/v2/classification_trees?filter[created_since]=2018-03-28T23:57).
