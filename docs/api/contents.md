# Abfragen von Inhalten über die Datenschnittstelle

Einheitlicher Datenendpunkt gespeicherte Suchen / Klassifizierungen


## Filtern von Inhalten

Häufig ist es so, dass neben der Einschränkung von Inhalten im Zuge der Erstellung eines Datenendpunkts auch eine nachträgliche Filterung direkt beim Abrufen der Inhalte wünschenswert bzw. notwendig ist. Bei dataCycle stehen deshalb unterschiedliche Filter zur Verfügung, die direkt über die API genutzt werden können. Um unterschiedliche Anwendungsfälle möglichst gut abdecken zu können, stehen unterschiedliche Typen von Filtern zu Verfügung. Der grundsätzliche Aufbau ist dabei aber immer der Gleiche: Alle Filter beginnen mit ```filter[TYPE]```. Je nach ausgewähltem Filtertyp unterscheidet sich die restliche Filterkonfiguration und ist auf den jeweiligen Filter abgestimmt. Die API unterstützt das Abfragen und auch das Filtern von Inhalten sowohl über **HTTP-GET** als auch über **HTTP-POST**, im Falle einer POST-Abfrage müssen die Parameter im **JSON**-Format an dataCycle übermittelt werden. Die folgenden Abfragen sind damit also equivalent und liefern auch exakt die gleichen Inhalte aus:

Alle Parameter aus der User-Story


#### HTTP-GET:

_/api/v4/endpoints/ffa78ef5-6e6a-47fa-a817-a771390d48dc?filter[classifications][in][withSubtree][]=3b9b4787-99e5-47c1-8d09-db65c1db43cc_

#### HTTP-POST:

 _/api/v4/endpoints/ffa78ef5-6e6a-47fa-a817-a771390d48dc_

```javascript
{
  "token": "YOUR_ACCESS_TOKEN",
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
          "b482d10a-8101-45aa-80e7-1a74884f5401,28505016-25d9-4ed8-a8ab-fc432a46e1af", // Gallerie ODER Museum
          "a1a626c2-3324-4118-b71b-aaecd10bd775" // UND barrierefrei
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
