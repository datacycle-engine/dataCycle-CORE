# Datenschnittstelle

Damit Daten von dataCycle abgerufen werden können, stehen zwei verschiedene Arten von Datenendpunkten zur Verfügung - _Klassifzierungs-Datenendpunkte_ und _Inhalts-Datenendpunkte_.

__Klassifizierungen__ können über allgemein zugängliche Datenendpunkte abgefragt werden (siehe [Abfragen von Klassifizierungen über die Datenschnittstelle](/docs/api/classifications)). Als Einstiegspunkt kann z.B. die Liste aller vorhandenen Klassifizierungsbäume ([/api/v4/concept_schemes](/api/v4/concept_schemes)) genutzt werden.

Die eigentlichen __Inhalte__ (z.B. Artikel, Veranstaltungen, Bilder, POIs, ...) können über beliebige Datenendpunkte, sogenannte Ad-Hoc-Datenendpunkte (siehe [Abfragen von Inhalten über die Datenschnittstelle](/docs/api/contents)), ausgeliefert werden. Diese lassen sich über die grafische Benutzeroberfläche mittels kombinierbarer Filter vorbereiten. In weiterer Folge können sie für ausgewählte Benutzer freigegeben und somit über die Datenschnittstelle verfügbar gemacht werden. Auch eine Änderung im Nachhinein ist jederzeit möglich. Sobald die zu einem Datenendpunkt gehörige Filterkonfiguration geändert und gespeichert wird, werden bei einer neuerlichen Datenabfrage die angepassten Filter unmittelbar berücksichtigt.

## Allgemeine Konzepte

### Datenformat

Die Datenschnittstelle verwendet für die Ausgabe der Daten so weit wie möglich offene Standards. Das grundsätzliche Datenformat entspricht weitestgehend [JSON-LD](https://www.w3.org/TR/json-ld/), wobei die im Standard nicht vorgesehen Teile bzw. Ergänzungen in erster Linie dazu dienen, die Datenschnittstelle für Entwickler benutzerfreundlicher zu gestalten. Neben den laut [JSON-LD](https://www.w3.org/TR/json-ld/) vorgesehen Wurzelelementen [@context](https://www.w3.org/TR/json-ld/#the-context) und [@graph](https://www.w3.org/TR/json-ld/#named-graphs) gibt es die beiden zusätzlichen Elemente ```meta``` und ```links```. Über das Element ```meta``` wird Zusatzinformation zu den ausgelieferten Inhalten bereitgestellt. Das sind beispielsweise die Anzahl der über den jeweiligen Datenendpunkt verfügbaren Inhalte oder der Titel einer Inhaltssammlung. Das Element ```links``` bietet einen vereinfachten und direkten Zugriff auf den Paging-Mechanismus und ermöglicht ein Blättern in den bereitgestellten Inhalten.


### Klassifizierungen

Bei der Auslieferung von Klassifizierungen über die Datenschnittstelle setzt dataCycle auf den [SKOS](https://www.w3.org/TR/skos-reference/)-Standard. Damit können nahezu beliebig komplexe Zusammenhänge zwischen Klassifizierungen abgebildet werden. Der Standard erlaubt es außerdem, unterschiedliche und unabhängige Klassifierungsschemata abzubilden. Insbesondere Verknüpfungen zwischen Klassifizierungen können sehr flexibel modelliert und dargestellt werden. dataCycle macht dabei eine wesentliche Einschränkung gegenüber dem vollen Potential von SKOS: Derzeit werden, um die ohnehin bereits recht komplexe Klassifizierungsmechanik etwas übersichtlicher zu halten, ausschließlich streng hierarchische Klassifizierungsbäume und keine Graphen unterstützt.

_Siehe auch [Abfragen von Klassifizierungen über die Datenschnittstelle](/docs/api/classifications)_


### Inhalte

Das bei der Auslieferung von Inhalten verwendete Vokabular greift - zumindest in Bezug auf die für den tatsächlichen Inhalt verwendeten Attribute - im Wesentlichen auf die Definitionen von [schema.org](https://schema.org) zurück. Es ist zwar grundsätzlich möglich, dieses Vokabular um zusätzliche Attribute zu erweitern, das wird aber so gut wie möglich vermieden und nur in speziellen Fällen zur Anwendung gebracht. Neben den für den eigentlichen Inhalt verwendeten Attributen, gibt es einige Ergänzungen, die in der Regel dafür verwendet werden, um den Umgang mit der API für Entwickler komfortabler zu gestalten. Eine wichtige Ausnahme bildet das Attribut ```dc:classification```, das dazu verwendet wird, um die mittels [SKOS](https://www.w3.org/TR/skos-reference/) abgebildeten Klassifizierungen mit den Inhalten zu verknüpfen. Grund für dieses zusätzliche Attribut ist, dass im Vokabular von [schema.org](https://schema.org) derzeit keine ausreichend gute Möglichkeit besteht, komplexere Klassifizierungssystematiken zu verwenden.

_Siehe auch [Abfragen von Inhalten über die Datenschnittstelle](/docs/api/contents)_


### Paging

Viele Endpunkte der Datenschnittstelle liefern eine größere Anzahl an Datensätzen aus. Um diese Daten trotzdem mit schnellen Antwortzeiten ausliefern zu können, greift dataCycle auf einen Paging-Mechanismus zurück und liefert große Datenmengen häppchenweise aus. Die Parametrisierung des Pagings hält sich dabei an die Empfehlungen von [JSON API](http://jsonapi.org/format/#fetching-pagination) und erfolgt über die folgenden, optionalen Parameter:

* **page[size]**: Seitengröße / Anzahl der Datensätze pro ausgelieferter Seite
* **page[number]**: Seitenzahl

Um die Handhabung des Pagings zu erleichtern, gibt es einige zusätzliche Attribute, damit z.B. die Gesamtanzahl der verfügbaren Datensätze auf jeder Seite zur Verfügung steht.


#### HTTP-GET

_/api/v4/concept_schemes?page[size]=25&page[number]=2_

#### HTTP-POST

_/api/v4/concept_schemes_

```javascript
{
  "token": "YOUR_ACCESS_TOKEN",
  "page": {
    "size": 25,
    "number": 2
    }
  }
}
```

#### Antwort

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

Für die Authentifizierung stehen bei der Datenschnittstelle von dataCycle mehrere Möglichkeiten zur Verfügung. Ist ein Benutzer bereits über das Frontend eingeloggt, ist eine Authentifzierung nicht notwendig, da in diesem Fall bereits eine aktive Session existiert und diese auch für die API weiter verwendet werden kann.

Die einfachste reguläre Authentifizierungs-Variante ist ein sogenanntes _Authentifzierungs-Token_, das beim Aufruf eines Datenendpunktes mit übergeben werden muss. Eine Übersicht über alle in einem System vorhandenen Klassifizierungbäume erhält man beispielsweise über [/api/v4/concept_schemes?token=MY_TOKEN](/api/v4/concept_schemes).

Eine weitere Variante ist die Verwendung eines sogenannten [Bearer-Tokens](https://datatracker.ietf.org/doc/html/rfc6750). Dabei wird die Authentifizierung über einen HTTP-Header abgewickelt. Der Zugriff auf die vorhandenen Klassifizierungsbäume funktioniert dabei folgendermaßen:

```bash
curl --url https://MY_DATACYCLE_URL/api/v4/concept_schemes \
     --header 'Authorization: Bearer MY_TOKEN' \
     --header 'Content-Type: application/json'
```

Neben den beiden token-basierten Authentifizierungs-Varianten wird auch [Basic Auth](https://datatracker.ietf.org/doc/html/rfc7617) mit Benutzername (bzw. E-Mailadresse) und Passwort unterstützt.


#### Authentifizierung über einen externen Dienst

Häufig ist es so, dass in Organisationen, die auch dataCycle nutzen, ein zentraler Dienst für die Benutzerverwaltung verwendet wird. Um den so verwalteten Benutzern auch einen einfachen Zugang zur Datenschnittstelle von dataCycle zu ermöglichen, werden bei den tokenbasierten Authentifizierungs-Varianten neben den internen dataCycle-Tokens auch [JSON Web Tokens](https://www.rfc-editor.org/rfc/rfc7519) unterstützt.


### Verknüpfte Inhalte

Ohne eine speziell formulierte Abfrage wird bei dataCycle nur die erste Ebene der angefragten Inhalte ausgeliefert. Verknüpfungen werden lediglich in Form von Referenzen mit den jeweiligen IDs über die Schnittstelle ausgeliefert. Eine Person mit einem verknüpften Foto wird dabei z.B. in der folgenden Form ausgeliefert:

```javascript
{
  "@context": {
    // ...
  },
  "@id": "ccc89b02-d918-463d-8c97-289f96de99c1",
  "@type": "Person",
  "name": "Timothy John Berners-Lee"
  "honorificPrefix": "Sir",
  "givenName": "Timothy John",
  "familyName": "Berners-Lee",
  "image": [{
    "@id": "a7336c10-5c7d-47de-9ca1-5c8c04fbe65e",
    "@type": "ImageObject",
    "name": "Tim Berners-Lee, 2014"
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
  "name": "Sir Timothy John Berners-Lee",
  "honorificPrefix": "Sir",
  "givenName": "Timothy John",
  "familyName": "Berners-Lee",
  "image": [{
    "@id": "a7336c10-5c7d-47de-9ca1-5c8c04fbe65e",
    "@type": "ImageObject",
    "name": "Tim Berners-Lee, 2014",
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

Das Inkludieren von verknüpften Inhalten funktioniert dabei nicht nur auf einer Ebene, sondern ist beliebig kaskadierbar. Mit dem zusätzlichen Parameter ```include=image.author``` kann beispielsweise erreicht werden, dass zusätzlich zum Bild selbst auch der Fotograf (über das Attribut [author](https://schema.org/author)) vollständig ausgeliefert wird:

```javascript
{
  "@context": {
    // ...
  },
  "@id": "ccc89b02-d918-463d-8c97-289f96de99c1",
  "@type": "Person",
  "name": "Sir Timothy John Berners-Lee",
  "honorificPrefix": "Sir",
  "givenName": "Timothy John",
  "familyName": "Berners-Lee",
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

Bei importieren Datensätzen besteht auch die Möglichkeit die IDs des externen Systems anzeigen zu lassen. Mit ```fields=identifier``` oder alternativ ```include=identifier``` werden diese eingeblendet, um z.B. die Duplikatssuche zu vereinfachen. Standardmäßig werden diese Informationen von der API nicht ausgeliefert.
