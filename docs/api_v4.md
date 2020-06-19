# Datenschnittstelle

Über die grafische Benutzeroberfläche können mittels kombinierbarer Filter beliebige Datenendpunkte erstellt werden. Diese können in weiterer Folge für ausgewählte Benutzer freigegeben und somit über die Datenschnittstelle verfügbar gemacht werden. Auch eine Änderung im Nachhinein ist jederzeit möglich. Sobald die zu einem Datenendpunkt gehörige Filterkonfiguration geändert und gespeichert wird, werden bei einer neuerlichen Datenabfrage die angepassten Filter unmittelbar berücksichtigt.

## Allgemeine Konzepte

### Datenformat

Die Datenschnittstelle verwendet für die Ausgabe der Daten so weit wie möglich offene Standards. Das grundsätzliche Datenformat entspricht weitestgehend [JSON-LD](https://www.w3.org/TR/json-ld/), wobei die im Standard nicht vorgesehen Teile bzw. Ergänzungen in erster Linie dazu dienen, die Datenschnittstelle für Entwickler benutzerfreundlicher zu gestalten. Neben den laut [JSON-LD](https://www.w3.org/TR/json-ld/) vorgesehen Wurzelelementen [@context](https://www.w3.org/TR/json-ld/#the-context) und [@graph](https://www.w3.org/TR/json-ld/#named-graphs) gibt es die beiden zusätzlichen Elemente ```meta``` und ```links```. Über das Element ```meta``` wird Zusatzinformation zu den ausgelieferten Inhalten bereitgestellt, wie beispielsweise die Anzahl der über den jeweiligen Datenendpunkt verfügbaren Inhalte oder der Titel einer Inhaltssammlung. Das Element ```links``` bietet einen vereinfachten und direkten Zugriff auf den Paging-Mechanismus und ermöglicht ein seitenweises Blättern in den bereitgestellten Inhalten.


### Klassifizierungen

Bei der Auslieferung von Klassifizierungen über die Datenschnittstelle setzt dataCycle auf den [SKOS](https://www.w3.org/TR/skos-reference/)-Standard. Damit können nahezu beliebig komplexe Zusammenhänge zwischen Klassifizierungen abgebildet werden. Der Standard erlaubt es außerdem, unterschiedliche und unabhängige Klassifierungsschemata abzubilden. Insbesondere Verknüpfungen zwischen Klassifizierungen können sehr flexibel modelliert und dargestellt werden. dataCycle macht dabei eine wesentliche Einschränkung gegenüber dem vollen Potential von SKOS: Derzeit werden, um die ohnehin bereits recht komplexe Klassifizierungsmechanik etwas übersichtlicher zu halten, ausschließlich streng hierarchische Klassifizierungsbäume und keine Graphen unterstützt.


### Inhalte

Das bei der Auslieferung von Inhalten verwendete Vokabular greift - zumindest in Bezug auf für den tatsächlichen Inhalt verwendete Attribute - im Wesentlichen auf die Definitionen von [schema.org](https://schema.org) zurück. Es ist zwar grundsätzlich möglich, dieses Vokabular um zusätzliche Attribute zu erweitern, das wird aber so gut wie möglich vermieden und nur in speziellen Fällen zur Anwendung gebracht. Neben den für den eigentlichen Inhalt verwendeten Attributen, gibt es einige Ergänzungen die in der Regel dafür verwendet werden, um den Umgang mit der API für Entwickler komfortabler zu gestalten. Eine wichtige Ausnahme bildet das Attribut ```dc:classification```, das dazu verwendet wird, um die mittels [SKOS](https://www.w3.org/TR/skos-reference/) abgebildeten Klassifizierungen mit den Inhalten zu verknüpfen. Grund für dieses zusätzliche Attribut ist, dass im Vokabular von [schema.org](https://schema.org) derzeit keine ausreichend gute Möglichkeit besteht, komplexere Klassifizierungssystematiken zu verwenden.


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

Die Authentifizierung erfolgt über ein sogenanntes _Authentifzierungs-Token_, das beim Aufruf eines Datenendpunktes mit übergeben werden muss. Ist ein Benutzer bereits über das Frontend eingeloggt, kann dieses Token weggelassen werden, da in diesem Fall bereits eine aktive Session existiert und diese auch für die API weiter verwendet werden kann. Eine Übersicht über alle in einem System vorhandenen Klassifizierungbäume erhält man beispielsweise über [/api/v4/concept_schemes?token=MY_TOKEN](/api/v4/concept_schemes).


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

## Filtern von Inhalten

Häufig ist es so, dass neben der Einschränkung von Inhalten im Zuge der Erstellung eines Datenendpunkts auch eine nachträgliche Filterung direkt beim Abrufen der Inhalte wünschenswert bzw. notwendig ist. Bei dataCycle stehen deshalb unterschiedliche Filter zur Verfügung, die direkt über die API genutzt werden können. Um unterschiedliche Anwendungsfälle möglichst gut abdecken zu können, stehen unterschiedliche Typen von Filtern zu Verfügung. Der grundsätzliche Aufbau ist dabei aber immer der Gleiche: Alle Filter beginnen mit ```filter[TYPE]```. Je nach ausgewähltem Filtertyp unterscheidet sich die restliche Filterkonfiguration und ist auf den jeweiligen Filter abgestimmt. Die API unterstützt das Abfragen und auch das Filtern von Inhalten sowohl über **HTTP-GET** als auch über **HTTP-POST**, im Falle einer POST-Abfrage müssen die Parameter im **JSON**-Format an dataCycle übermittelt werden. Die folgenden Abfragen sind damit also equivalent und liefern auch exakt die gleichen Inhalte aus:

#### HTTP-GET:

_/api/v4/endpoints/ffa78ef5-6e6a-47fa-a817-a771390d48dc?filter[classifications][in][withSubtree][]=3b9b4787-99e5-47c1-8d09-db65c1db43cc_

#### HTTP-POST:

 _/api/v4/endpoints/ffa78ef5-6e6a-47fa-a817-a771390d48dc_

```javascript
{
  "filter": {
		"classifications": {
			"in": {
				"withSubtree": ["3b9b4787-99e5-47c1-8d09-db65c1db43cc"]
			}
		}
	}
}
```

***ACHTUNG: Bei der Übergabe von Filterparametern über HTTP-POST ist es wichtig, darauf zu achten, dass die einzelnen Komponenten je nach verwendetem Filter exakt den Vorgaben entsprechend entweder als Array oder als String übergeben werden!***

Die Nutzung von HTTP-POST bringt vor allem im Zusammenhang mit komplexen Abfragen einen Vorteil, weil diese in der Regel sehr viel übersichtlicher gestaltet werden können. Außerdem unterliegen sie nicht der Längenbeschränkung von URLs, die wiederum bei sehr komplexen bzw. umfangreichen Abfragen ein Problem verursachen könnte.


### Klassifizierungen - **filter\[classifications\]**

Eine Option, um die über den Datenendpunkt vordefinierte Filterung weiter zu verfeinern, ist durch das Einschränken der Inhalte auf Basis von Klassifizierungen. Sie können dabei sowohl als notwendiges als auch als ausschließendes Kriterium verwendet werden. Wird die Klassifizierung als notwendiges Kriterium übergeben, werden nur Inhalte ausgeliefert, die mit einer bestimmten Klassifizierung wie z.B. "Inhaltstypen > Ort > Öffentliche Einrichtung > Museum" verknüpft sind. Im Fall einer ausschließenden Verwendung werden eben diese Inhalte ausgeschlossen. Außerdem kann festgelegt werden ob Sub-Klassifizierungen bei der Filterung mit berücksichtigt werden oder nicht. Im Detail ergeben sich damit die folgenden Kombinationsmöglichkeiten:

#### filter\[classifications\]\[in\]\[withSubtree\]\[\]:

Inhalte müssen mit einer der übergebenen Klassifizierungen oder einer zugehörigen Sub-Klassifizierung verknüpft sein, um bei der Abfrage berücksichtigt zu werden.


#### filter\[classifications\]\[in\]\[withoutSubtree\]\[\]:

Inhalte müssen mit einer der übergebenen Klassifizierungen verknüpft sein. Eine indirekte Verknüpfung über eine Sub-Klassifizierung wird bei dieser Art der Abfrage nicht berücksichtigt. (Sehr wohl berücksichtigt werden aber indirekte Verknüpfung, die sich aufgrund eines Klassifizierungs-Mappings ergeben.)


#### filter\[classifications\]\[notIn\]\[withSubtree\]\[\]:

Inhalte dürfen nicht mit einer der übergebenen Klassifizierungen oder einer zugehörigen Sub-Klassifizierung verknüpft sein.


#### filter\[classifications\]\[notIn\]\[withoutSubtree\]\[\]:

Inhalte dürfen nicht mit einer der übergebenen Klassifizierungen verknüpft sein.


Die einzelnen Filter können dabei beliebig kombiniert werden, um eine maximale Flexibilität zu erlauben. Außerm ist es möglich die übergebenen Klassifizierungen sowohl mit UND als auch mit einem ODER zu verknüpfen. Für eine UND-Verknüpfung müssen die Klassifizierungen als separate Elemente eines Arrays übergeben werden, für eine ODER-Verknüpfung in Form einer kommagetrennten Liste innerhalb eines einzelnen Strings. Um beispielsweise nach Gallerien oder Museen zu suchen, die barrierefrei zugänglich sind und die keinen Schwerpunkt auf moderne Kunst setzen, könnte die folgende Abfrage verwendet werden:

```
{
  "filter": {
    "classifications": {
      "in": {
        "withSubtree": [
          "b482d10a-8101-45aa-80e7-1a74884f5401,28505016-25d9-4ed8-a8ab-fc432a46e1af", // Gallerie, Museum
          "a1a626c2-3324-4118-b71b-aaecd10bd775" // barrierefrei
        ]
      },
      "notIn": {
        "withSubtree": [
          "cae91ec2-7b32-44e2-ad99-26c5d1fe7ff5" // Moderne Kunst
        ]
      }
    }
  }		
}
```

<!--
### Attribute - **filter\[attribute\]**

Eine weitere Option um Inhalte zu filter, ist auf Basis von ausgewählten Attributen.


#### Aktualisierungen

Für einige Anwendungsfälle kann es hilfreich sein, herauszufinden zu können, welche Datensätze innerhalb einer vorgegeben Zeitspanne erstellt, geändert bzw. gelöscht worden sind. Zu diesem Zweck können bei API-Endpunkten, die auch Paging unterstützen, spezielle ```filter```-Parameter genutzt werden. Dadurch kann die Anzahl der Datensätze, die geladen werden muss, erheblich reduziert werden. Außerdem muss die Prüfung, ob es seit dem letzten Update neue Änderungen gegeben hat, nicht client-seitig durchgeführt werden, wodurch die Client-Anwendung noch einmal deutlich entlastet werden kann. Für diese Art der Filterung können sogenannte _Attribut-Filter_ genutzt werden, wobei die folgenden Attribute unterstützt werden:

* **createdAt**
* **modifiedAt**
* **deletedAt**

Bei dieser speziellen Art von _Attribut-Filtern_ muss neben dem Attribut, auf dessen Basis die Filterung durchgeführt werden soll, auch ein Zeitraum übergeben werden. Unterstützt werden an dieser Stelle sowohl beschränkte Intervalle mit einer unteren (**filter\[attribute\]\[ATTRIBUTE_NAME\]\[in\]\[min\]**) und einer oberen Schranke ((**filter\[attribute\]\[ATTRIBUTE_NAME\]\[in\]\[max\]**)) als auch einseitig unbeschränkte Intervalle mit entweder einer oberen oder einer unteren Schranke. Die Zeitpunkte müssen dabei entsprechend den Vorgaben von [RFC 3339](https://tools.ietf.org/html/rfc3339) übergeben werden.  Ein Filter für Inhalte, die am 21. Oktober 2015 geändert worden sind, kann beispielsweise über [/api/v4/endpoints/ffa78ef5-6e6a-47fa-a817-a771390d48dc?filter\[attribute\]\[modifiedAt\]\[in\]\[min\]=2015-10-21&filter\[attribute\]\[modifiedAt\]\[in\]\[max\]=2015-10-21](/api/v4/endpoints/ffa78ef5-6e6a-47fa-a817-a771390d48dc?filter\[attribute\]\[modifiedAt\]\[in\]\[min\]=2015-10-21&filter\[attribute\]\[modifiedAt\]\[in\]\[max\]=2015-10-21)" abgebildet werden.

Der Zeitpunkt der Erstellung und der letzten Aktualisierung können nicht nur für die Filterung direkt beim Abrufen von Inhalten genutzt werden, sie stehen in Form der Attribute ```dct:created``` bzw. ```dct:modified``` bei Bedarf auch direkt bei den einzelnen Inhalten zur Verfügung, sie müssen aber explizit über den zusätzlichen Parameter ```fields``` abgefragt werden. -->
