# Datenschnittstelle

Über die grafische Benutzeroberfläche können mittels kombinierbarer Filter beliebige Datenendpunkte erstellt werden. Diese können in weiterer Folge für ausgewählte Benutzer freigegeben und somit über die Datenschnittstelle verfügbar gemacht werden. Auch eine Änderung im Nachhinein ist jederzeit möglich. Sobald die zu einem Datenendpunkt gehörige Filterkonfiguration geändert und gespeichert wird, werden bei einer neuerlichen Datenabfrage die angepassten Filter unmittelbar berücksichtigt.

## Allgemeine Konzepte

### Datenformat

Die Datenschnittstelle verwendet für die Ausgabe der Daten so weit wie möglich offene Standards. Das grundsätzliche Datenformat entspricht weitestgehend [JSON-LD](https://www.w3.org/TR/json-ld/), wobei die im Standard nicht vorgesehen Teile bzw. Ergänzungen in erster Linie dazu dienen, die Datenschnittstelle für Entwickler benutzerfreundlicher zu gestalten. Neben den laut [JSON-LD](https://www.w3.org/TR/json-ld/) vorgesehen Wurzelelementen [@context](https://www.w3.org/TR/json-ld/#the-context) und [@graph](https://www.w3.org/TR/json-ld/#named-graphs) gibt es die beiden zusätzlichen Elemente ```meta``` und ```links```. Über das Element ```meta``` wird Zusatzinformation zu den ausgelieferten Inhalten bereitgestellt, wie beispielsweise die Anzahl der über den jeweiligen Datenendpunkt verfügbaren Inhalte oder der Titel einer Inhaltssammlung. Das Element ```links``` bietet einen vereinfachten und direkten Zugriff auf den Paging-Mechanismus und ermöglicht ein seitenweises blättern in den bereitgestellten Inhalten.


### Paging

Viele Endpunkte der Datenschnittstelle liefern eine größere Anzahl an Datensätzen aus. Um diese Daten trotzdem mit schnellen Antwortzeiten ausliefern zu können, greift dataCycle auf einen Paging-Mechanismus zurück und liefert große Datenmengen häppchenweise aus. Die Parametrisierung des Pagings hält sich dabei an die Empfehlungen von [JSON API](http://jsonapi.org/format/#fetching-pagination) und erfolgt über die folgenden, optionalen Parameter:

* **page[size]**: Seitengröße / Anzahl der Datensätze pro ausgelieferter Seite
* **page[number]**: Seitenzahl

Um die Handundhabung des Pagings zu erleichtern, gibt es einige zusätzliche Attribute, damit z.B. die Gesamtanzahl der verfügbaren Datensätze auf jeder Seite zur Verfügung steht.

```javascript
{
  @context: {
    // ...
  },
  @graph: [{
    // ...
  }],
  meta: {
    total: 71,
    pages: 3
  },
  links: {
    prev: '/api/v4/concept_schemes?page[size]=25&page[number]=1',
    next: '/api/v4/concept_schemes?page[size]=25&page[number]=3',
  }
}
```

Die Gesamtanzahl wird innerhalb des ```meta```-Attributs mit dem Namen ```total``` ausgeliefert. An dieser Stelle wird außerdem die Anzahl der Seiten, die sich aufgrund der aktuellen Seitengröße ergibt, dargestellt. Zusätzlich dazu werden Links zur nächsten bzw. vorigen Seite innerhalb des ```links```-Attributs ausgeliefert.


### Authentifizierung

Die Authentifizierung erfolgt über ein sogenanntes _Authentifzierungs-Token_, dass beim Aufruf eines Datenendpunktes mit übergeben werden muss. Ist ein Benutzer bereits über das Frontend eingeloggt, kann dieses Token weggelassen werden, da in diesem Fall bereits eine aktive Session existiert und diese auch für die API weiter verwendet werden kann. Eine Übersicht über alle in einem System vorhandenen Klassifizierungbäume erhält man beispielsweise über [/api/v4/concept_schemes?token=MY_TOKEN](/api/v4/concept_schemes).


### Aktualisierungen

Für einige Anwendungsfälle kann es hilfreich sein, herauszufinden zu können, welche Datensätze innerhalb einer vorgegeben Zeitspanne geändert worden sind. Zu diesem Zweck können bei API-Endpunkten, über die mehrere Inhalte auf der gleichen Ebene ausgeliefert werden, also grundsätzliche alle Endpunkte, die auch Paging unterstützen, zusätzliche ```filter```-Parameter genutzt werden. Dadurch kann die Anzahl der Datensätze, die geladen werden muss, erheblich reduziert werden. Außerdem muss die Prüfung, ob es seit dem letzten Update neue Änderungen gegeben hat, nicht client-seitig durchgeführt werden, wodurch die Client-Anwendung noch einmal deutlich entlastet werden kann. Die Filter die für diesen Mechanismus genutzt werden können sehen folgendermaßen aus:

* **filter[created_since]**: Es werden nur Datensätzen ausgeliefert, die seit dem übergebenen Zeitpunkt erstellt worden sind
* **filter[modified_since]**: Es werden nur Datensätzen ausgeliefert, die sich seit dem übergebenen Zeitpunkt geändert haben

Der Zeitpunkt muss dabei entsprechend den Vorgaben von [RFC 3339](https://tools.ietf.org/html/rfc3339) übergeben werden. Eine Anfrage könnte beispielsweise folgendermaßen aussehen: [/api/v4/concept_schemes?filter[created_since]=2019-12-09T23:57](/api/v4/concept_schemes?filter[created_since]=2019-12-09T23:57).

Der Zeitpunkt der Erstellung und der letzten Aktualisierung können nicht nur für die Filterung direkt beim Abrufen von Inhalten genutzt werden, sie stehen in Form der Attribute ```dct:created``` bzw. ```dct:modified``` bei Bedarf auch direkt bei den einzelnen Inhalten zur Verfügung.


### Verknüpfte Inhalte

Ohne eine speziell formulierte Abfrage, wird bei dataCycle nur die erste Ebene der angefragten Inhalten ausgeliefert, Verknüpfungen werden lediglich in Form von Referenzen mit den jeweiligen IDs über die Schnittstelle ausgeliefert. Eine Person mit einem verknüpften Foto, wird dabei z.B. in der folgenden Form ausgeliefert:

```javascript
{
  "@context": {
    // ...
  },
  "@id": "ccc89b02-d918-463d-8c97-289f96de99c1",
  "@type": "Person",
  "honorificPrefix": "Sir",
  "givenName": "Timothy John",
  "familyName": "Berners-Lee",
  "image": [{
    "@id": "a7336c10-5c7d-47de-9ca1-5c8c04fbe65e",
    "@type": "ImageObject"
  }]
}
```

Über den optionalen URL-Parameter ```include``` gefolgt vom Namen des Attributs, über das die Verknüpfung abgebildet ist - also z.B. ```include=image``` - können alle Attribute des verknüpften Inhalts mit abgefragt werden. Das obige Beispiel würde in diesem Fall inklusive der Attribute für das Bild der abgefragten Person folgendermaßen bereitgestellt:

```javascript
{
  "@context": {
    // ...
  },
  "@id": "ccc89b02-d918-463d-8c97-289f96de99c1",
  "@type": "Person",
  "honorificPrefix": "Sir",
  "givenName": "Timothy John",
  "familyName": "Berners-Lee",
  "name": "Sir Timothy John Berners-Lee",
  "image": [{
    "@id": "a7336c10-5c7d-47de-9ca1-5c8c04fbe65e",
    "@type": "ImageObject",
    "caption": "Tim Berners-Lee, 2014",
    "contentUrl": "https://upload.wikimedia.org/wikipedia/commons/9/9d/Sir_Tim_Berners-Lee.jpg",
    "thumbnailUrl": "https://upload.wikimedia.org/wikipedia/commons/thumb/9/9d/Sir_Tim_Berners-Lee.jpg/440px-Sir_Tim_Berners-Lee.jpg",
    "author": [{
      "@id": "b1f8a88b-2649-42c4-974d-f9cb351ff263",
      "@type": "Person"
    }]
  }]
}
```

Das inkludieren von verknüpften Inhalten funktionert dabei nicht nur auf einer Ebene sondern ist beliebig kaskadierbar. Mit dem zusätzlichen Parameter ```include=image.author``` kann beispielsweise erreicht werden, dass zusätzlich zum Bild selbst auch der Photograph vollständig ausgeliefert wird:

```javascript
{
  "@context": {
    // ...
  },
  "@id": "ccc89b02-d918-463d-8c97-289f96de99c1",
  "@type": "Person",
  "honorificPrefix": "Sir",
  "givenName": "Timothy John",
  "familyName": "Berners-Lee",
  "name": "Sir Timothy John Berners-Lee",
  "image": [{
    "@id": "a7336c10-5c7d-47de-9ca1-5c8c04fbe65e",
    "@type": "ImageObject",
    "caption": "Tim Berners-Lee, 2014",
    "contentUrl": "https://upload.wikimedia.org/wikipedia/commons/9/9d/Sir_Tim_Berners-Lee.jpg",
    "thumbnailUrl": "https://upload.wikimedia.org/wikipedia/commons/thumb/9/9d/Sir_Tim_Berners-Lee.jpg/440px-Sir_Tim_Berners-Lee.jpg",
    "author": [{
      "@id": "b1f8a88b-2649-42c4-974d-f9cb351ff263",
      "@type": "Person",
      "givenName": "Paul",
      "familyName": "Clarke",
      "name": "Paul Clarke"
    }]
  }]
}
```


### Abfragen von ausgewählten Attributen

Für viele Anwendungen ist es nicht notwendig, Inhalte vollständig von der Datenschnittstelle herunterzuladen, da oft nur ein Teil der Attribute für die jeweilige Darstellung benötigt wird. In dataCycle ist es deshalb möglich, bereits bei der Abfrage vorzugeben, welche Attribute im Ergebnis einer Anfrage enthalten sein sollen. Das kann über den optionalen URL-Parameter ```fields``` gesteuert werden. Um z.B. nur den Namen einer Person vom Server abzufragen, kann das über den URL-Parameter ```fields=name``` erreicht werden. Ähnlich wie der Parameter ```include``` für verknüpfte Inhalte, kann auch der Parameter ```fields``` in Kombination mit ```include``` beliebig kaskadiert werden. Mit der Parameter-Kombination ```include=image,image.author``` und ```fields=name,image.contentUrl,image.author.name``` erhält man beispielsweise das folgende Ergebnis:

```javascript
{
  "@context": {
    // ...
  },
  "@id": "ccc89b02-d918-463d-8c97-289f96de99c1",
  "@type": "Person",
  "name": "Sir Timothy John Berners-Lee",
  "image": [{
    "@id": "a7336c10-5c7d-47de-9ca1-5c8c04fbe65e",
    "@type": "ImageObject",
    "contentUrl": "https://upload.wikimedia.org/wikipedia/commons/9/9d/Sir_Tim_Berners-Lee.jpg",
    "author": [{
      "@id": "b1f8a88b-2649-42c4-974d-f9cb351ff263",
      "@type": "Person",
      "name": "Paul Clarke"
    }]
  }]
}
```

## Klassifizierungen

Bei der Auslieferung von Klassifizierungen über die Datenschnittstelle setzt dataCycle auf den [SKOS](https://www.w3.org/TR/skos-reference/)-Standard. Damit können nahezu beliebig komplexe Zusammenhänge zwischen Klassifizierungen abgebildet werden. Der Standard erlaubt es außerdem, unterschiedliche und unabhängige Klassifierungsschemata abzubilden. Insbesondere Verknüpfungen zwischen Klassifizierungen können sehr flexibel modelliert und dargestellt werden. dataCycle macht dabei eine wesentliche Einschränkung gegenüber dem vollen Potential von SKOS: Derzeit werden, um die ohnehin bereits recht komplexe Klassifizierungsmechanik etwas übersichtlicher zu halten, ausschließlich streng hierarchische Klassifizierungsbäume und keine Graphen unterstützt.


## Inhalte

Das bei der Auslieferung von Inhalten verwendete Vokabular greift - zumindest in Bezug auf für den tatsächlichen Inhalt verwendete Attribute - im Wesentlichen auf die Definitionen von [schema.org](https://schema.org) zurück. Es ist zwar grundsätzlich möglich, dieses Vokabular um zusätzliche Attribute zu erweitern, das wir aber so gut wie möglich vermieden und nur in speziellen Fällen zur Anwendung gebracht. Neben den für den eigentlichen Inhalt verwendeten Attributen, gibt es einige Ergänzungen die in der Regel dafür verwendet werden, um den Umgang mit der API für Entwickler komfortabler zu gestalten. Einzige Ausnahme bildet das Attribut ```dc:classification```, das dazu verwendet wird, um die mittels [SKOS](https://www.w3.org/TR/skos-reference/) abgebildeten Klassifizierungen mit den Inhalten zu verknüpfen. Grund für dieses zusätzliche Attribut ist, dass im Vokabular von [schema.org](https://schema.org) derzeit keine Möglichkeit besteht, komplexere Klassifizierungssystematiken zu realisieren.


### Filtern von Inhalten auf Basis von Klassifizierungen

Neben der Möglichkeiten, Inhalte beim Anlegen von Datenendpunkten bereits zu filtern bzw. einzuschränken, können Inhalte auch beim Abrufen über die Datenschnittstelle weiter eingeschränkt werden. Eine Option, um diese Filterung zu verwenden, ist durch das Einschränken von Klassifizierungen. Über den optionalen URL-Parameter ```filter[concepts][]``` (in Anlehnung an die [SKOS](https://www.w3.org/TR/skos-reference/)-Nomenklatur) können Inhalte auf Basis der in Form von IDs übergebenen Klassifizierungen eingeschränkt werden. Mehrere Klassifizierungen können dabei für eine *ODER*-Verknüpfung (z.B.: ```filter[concepts][]=fa5b9d03-313e-4dd1-8ee5-4973f79b0e8d,1ea9a03c-ebd5-4d24-947f-2825553c9fa2,1cbff2fe-6105-47c3-9409-f10837578ca9```) durch ein Koma getrennt übergeben werden oder durch eine mehrfache Verwendung des Filter-Parameters als *UND*-Verknüpfung (z.B.: ```filter[concepts][]=23f76129-4a88-4fa9-9b74-8a9d3909b5c0&filter[concepts][]=cd1874e3-728d-4465-94ca-c59182525a35```).
