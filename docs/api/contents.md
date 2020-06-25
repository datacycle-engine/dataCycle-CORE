# Abfragen von Inhalten über die Datenschnittstelle

In dataCycle gibt es zwei Möglichkeiten, wie Inhalte über die Datenschnittstelle verfügbar gemacht werden können. Für eine von Hand ausgewählte Selektion von Inhalten können (statische) Inhaltssammlungen genutzt werden. Sollen Inhalte auf Basis von unterschiedlichen Filterkriterien automatisch ausgewählt werden, können gespeicherte Suchen bzw. "dynamische" Inhaltssammlungen genutzt werden. Über die Datenschnittstelle werden statische und dynamische Inhaltssammlungen über ein einheitliches URL-Schema (_**/api/v4/endpoints/ENDPOINT_ID**_) bereitgestellt.


## Filtern von Inhalten

Häufig ist es so, dass neben der Einschränkung von Inhalten im Zuge der Erstellung eines Datenendpunkts auch eine nachträgliche Filterung direkt beim Abrufen der Inhalte wünschenswert bzw. notwendig ist. Bei dataCycle stehen deshalb unterschiedliche Filter zur Verfügung, die direkt über die API genutzt werden können. Um unterschiedliche Anwendungsfälle möglichst gut abdecken zu können, stehen unterschiedliche Typen von Filtern zu Verfügung. Der grundsätzliche Aufbau der unterschiedlichen Filtertypen ist dabei aber immer sehr ähnlich: Alle Filter beginnen mit ```filter[TYPE]```. Je nach ausgewähltem Filtertyp unterscheidet sich die restliche Filterkonfiguration und ist auf den jeweiligen Filter abgestimmt.

Die API unterstützt das Abfragen und auch das Filtern von Inhalten sowohl über **HTTP-GET** als auch über **HTTP-POST**, im Falle einer POST-Abfrage müssen die Parameter im **JSON**-Format an dataCycle übermittelt werden. Die folgenden Abfragen sind damit also äquivalent und liefern auch exakt die gleichen Inhalte aus:

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

***ACHTUNG: Bei der Übergabe von Filterparametern sowohl über HTTP-GET als auch über HTTP-POST ist es wichtig, darauf zu achten, dass die einzelnen Komponenten je nach verwendetem Filter exakt den Vorgaben entsprechend entweder als Array oder als String übergeben werden!***

Die Nutzung von HTTP-POST bringt vor allem im Zusammenhang mit komplexen Abfragen einen Vorteil, weil diese in der Regel sehr viel übersichtlicher gestaltet werden können. Außerdem unterliegen sie nicht der Längenbeschränkung von URLs, die ebenfalls bei sehr komplexen bzw. umfangreichen Abfragen Probleme verursachen kann. Die folgende Abfrage, die alle derzeit verfügbaren Filtertypen verwendet, kann in Form eines JSON-Snippets im Gegensatz zu einer fast 1000 Zeichen langen URL immer noch sehr übersichtlich dargestellt werden:

```javascript
{
  "token": "YOUR_ACCESS_TOKEN",
  "filter": {
    "q": "Sommer",
    "classifications": {
      "in": {
        "withSubtree": [
          "b482d10a-8101-45aa-80e7-1a74884f5401,28505016-25d9-4ed8-a8ab-fc432a46e1af",
          "a1a626c2-3324-4118-b71b-aaecd10bd775"
        ]
      },
      "notIn": {
        "withSubtree": [
          "cae91ec2-7b32-44e2-ad99-26c5d1fe7ff5"
        ]
      }
    },
    "attribute": {
      "createdAt": {
        "in": {
          "min": "2020-03-16",
          "max": "2020-05-14"
        },
        "notIn": {
          "min": "2020-04-06",
          "max": "2020-04-13"
        }          
      }, {
        "schedule": {
          "in": {
            "min": "2020-06-21",
            "max": "2020-09-20"
          }
        }
      }
    },
    "geo": {
			"in": {
				"box": [9.53074836730957,46.37226867675781,17.160776138305664,49.020530700683594]
			}			
		}
  }
}
```

### Volltextsuche - **filter\[q\]**

Ein sehr häufiger Anwendungsfall um Inhalte einzuschränken ist eine Volltextsuche. Natürlich steht auch innerhalb von dataCycle über den Filterparameter **filter\[q\]** eine Volltextsuche zur Verfügung. Um beispielsweise nach Inhalten zum Thema "Musik" zu suchen, kann die folgende Suchanfrage an dataCycle übermittelt werden:

```javascript
{
  "token": "YOUR_ACCESS_TOKEN",
  "filter": {
    "q": "Musik"
  }
}
```

Alternativ kann diese Anfrage auch über **HTT-GET** umgesetzt werden:

_/api/v4/endpoints/ffa78ef5-6e6a-47fa-a817-a771390d48dc?token=YOUR_ACCESS_TOKEN&filter[q]=Musik_


### Klassifizierungen - **filter\[classifications\]**

Eine Option, um die über den Datenendpunkt vordefinierte Filterung weiter zu verfeinern, ist durch das Einschränken der Inhalte auf Basis von Klassifizierungen. Sie können dabei sowohl als notwendiges als auch als ausschließendes Kriterium verwendet werden. Wird die Klassifizierung als notwendiges Kriterium übergeben, werden nur Inhalte ausgeliefert, die mit einer bestimmten Klassifizierung wie z.B. "Inhaltstypen > Ort > Öffentliche Einrichtung > Museum" verknüpft sind. Im Fall einer ausschließenden Verwendung werden eben diese Inhalte ausgeschlossen. Außerdem kann festgelegt werden ob Sub-Klassifizierungen bei der Filterung berücksichtigt werden sollen oder nicht. Im Detail ergeben sich damit die folgenden Kombinationsmöglichkeiten:

#### filter\[classifications\]\[in\]\[withSubtree\]\[\]:

Inhalte müssen mit einer der übergebenen Klassifizierungen oder einer zugehörigen Sub-Klassifizierung verknüpft sein, um bei der Abfrage berücksichtigt zu werden.


#### filter\[classifications\]\[in\]\[withoutSubtree\]\[\]:

Inhalte müssen mit einer der übergebenen Klassifizierungen verknüpft sein. Eine indirekte Verknüpfung über eine Sub-Klassifizierung wird bei dieser Art der Abfrage nicht berücksichtigt. (_Sehr wohl berücksichtigt werden aber indirekte Verknüpfungen, die sich aufgrund eines Klassifizierungs-Mappings ergeben._)


#### filter\[classifications\]\[notIn\]\[withSubtree\]\[\]:

Inhalte dürfen nicht mit einer der übergebenen Klassifizierungen oder einer zugehörigen Sub-Klassifizierung verknüpft sein.


#### filter\[classifications\]\[notIn\]\[withoutSubtree\]\[\]:

Inhalte dürfen nicht mit einer der übergebenen Klassifizierungen verknüpft sein. Eine indirekte Verknüpfung über eine Sub-Klassifizierung wird bei dieser Art der Abfrage nicht berücksichtigt. (_Sehr wohl berücksichtigt werden aber indirekte Verknüpfungen, die sich aufgrund eines Klassifizierungs-Mappings ergeben._)


Um die Flexibilität des Klassifizierungsfilters noch weiter zu steigern, können die einzelnen Filterbausteine beliebig kombiniert werden, um eine maximale Flexibilität zu erlauben. Außerm ist es möglich die übergebenen Klassifizierungen sowohl mit **UND** als auch mit einem **ODER** zu verknüpfen. Für eine **UND**-Verknüpfung müssen die Klassifizierungen als separate Elemente eines Arrays übergeben werden, für eine **ODER**-Verknüpfung in Form einer kommagetrennten Liste innerhalb eines einzelnen Strings. Um beispielsweise nach Gallerien oder Museen zu suchen, die barrierefrei zugänglich sind und die derzeit keinen Schwerpunkt auf moderne Kunst gesetzt haben, könnte die folgende Abfrage verwendet werden:

```javascript
{
  "token": "YOUR_ACCESS_TOKEN",
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

### Attribute - **filter\[attribute\]**

Eine weitere Option um Inhalte zu filtern, ist auf Basis von ausgewählten Attributen. Welche Attribute bei dieser Art der Filterung unterstützt werden, kann individuell pro dataCycle-Instanz konfiguriert werden, insbesondere bei sehr individuellen Konfigurationen kann also nicht davon ausgegangen werden, dass alle Attribute uneingeschränkt unterstützt werden.

Derzeit können unterschiedliche Arten von numerischen Attributen, wie z.B. das Erstellungsdatum, ein Veranstaltungstermin oder die Breite eines Bildes, für die Filterung von Inhalten herangezogen werden. Da all diese numerischen Attribute als skalare Werte interpretieren werden können, stehen für alle Attribute die gleichen Filtermöglichkeiten zur Verfügung. Im Prinzip kann man sich diese Attribute immer als Wert auf einer Zahlengerade vorstellen. Möchte man nun eine Filterung durchführen, kann der relevante Bereich auf dieser Zahlengerade durch einen entsprechenden Filter eingeschränkt werden. Unterstützt werden an dieser Stelle sowohl beschränkte Intervalle mit einer unteren (**filter\[attribute\]\[*ATTRIBUTE_NAME*\]\[in\]\[min\]**) und einer oberen Schranke ((**filter\[attribute\]\[*ATTRIBUTE_NAME*\]\[in\]\[max\]**)) als auch einseitig unbeschränkte Intervalle mit entweder nur einer oberen oder nur einer unteren Schranke. Außerdem ist es möglich, das Intervall zu invertieren, sprich den Wertebereich außerhalb des angegebenen Intervalls auszuwählen (**filter\[attribute\]\[*ATTRIBUTE_NAME*\]\[notIn\]\[min\]** bzw. **filter\[attribute\]\[*ATTRIBUTE_NAME*\]\[notIn\]\[max\]**). Die übergebenen Intervalle werden von dataCycle immer als geschlossene Intervalle interpretiert, das heißt, die angegebenen Intervallgrenzen werden bei den damit festgelegten Wertebereichen eingeschlossen.
Um beispielsweise alle Veranstaltungen im Herbst und im Winter außer den Veranstaltungen zwischen den Weihnachtsfeiertagen auszuwählen, könnte folgende Filterkonfiguration genutzt werden:

```javascript
{
  "token": "YOUR_ACCESS_TOKEN",
  "filter": {
    "attribute": {
      "schedule": {
        "in": {
          "min": "2020-09-23",
          "max": "2021-03-20"
        },
        "notIn": {
          "min": "2020-12-24",
          "max": "2021-01-06"
        }
      }
    }
  }
}
```

#### Aktualisierungen - **filter\[attribute\]\[createdAt|modifiedAt|deletedAt\]**

Für einige Anwendungsfälle kann es hilfreich sein, herausfinden zu können, welche Datensätze innerhalb einer vorgegeben Zeitspanne erstellt, geändert oder gelöscht worden sind. Zu diesem Zweck können bei allen API-Endpunkten, die sich aus statischen bzw. dynamischen Inhaltssammlungen ergeben, spezielle _Attribut-Filter_ genutzt werden. Dadurch kann die Anzahl der Datensätze, die geladen werden muss, erheblich reduziert werden. Außerdem muss die Prüfung, ob es seit dem letzten Update neue Änderungen gegeben hat, nicht client-seitig durchgeführt werden, wodurch die auf dataCycle aufbauenden Anwendungen noch einmal deutlich entlastet werden können. Für diese Art der Filterung werden die folgenden Attribute unterstützt:

* **createdAt**
* **modifiedAt**
* **deletedAt** (_ACHTUNG: Dieser Filter steht nur über den speziellen Endpunkt [/api/v4/things/deleted](/api/v4/things/deleted) zur Verfügung!_)

Bei der Verwendung von Zeitpunkten im Rahmen eines Filterkriteriums müssen die Zeitpunkte entsprechend den Vorgaben von [RFC 3339](https://tools.ietf.org/html/rfc3339) übergeben werden, damit sie von dataCycle korrekt interpretiert werden können.

Sollen beispielsweise alle Inhalte ermittelt werden, die am "Marty-McFly-Day" erstellt worden sind, könnte der Filter folgendermaßen übergeben werden:

```javascript
{
  "token": "YOUR_ACCESS_TOKEN",
  "filter": {
    "attribute": {
      "createdAt": {
        "in": {
          "min": "2015-10-21",
          "max": "2015-10-21"
        }
      }
    }
  }
}
```

_Die Zeitpunkte der Erstellung und der letzten Aktualisierung können nicht nur für die Filterung direkt beim Abrufen von Inhalten genutzt werden. Sie können in Form der Attribute ```dct:created``` bzw. ```dct:modified``` bei Bedarf auch direkt bei den einzelnen Inhalten ausgegeben und weiter ausgewertet werden, sie müssen aber explizit über den zusätzlichen Parameter ```fields``` abgefragt werden._


#### Termine - **filter\[attribute\]\[schedule\]**

Sind Veranstaltungen im Datenbestand einer dataCycle-Instanz vorhanden, ist es in der Regel notwendig, diese Veranstaltungen auf Basis des Veranstaltungstermins zu filtern. Da in dataCycle wiederkehrende Veranstaltungstermine in Form von Regelsätzen hinterlegt werden können und nicht als Einzeltermine erfasst werden müssen, gibt es einen speziellen _Attribut-Filter_ für diesen Anwendungsfall. Es kann zwar auch bei diesem Filter ein bzw. mehrere Intervalle übergeben werden, im Gegensatz zu einfachen Zeitpunkten wird bei der Verwendung dieses Filters aber auch eine spezielle Sortierung, die spezifisch auf Termine abgestimmt worden ist, verwendet. Dabei werden Veranstaltungen nach dem ersten Termin im angegeben Zeitraum sortiert, wobei sehr lange dauernde Veranstaltungen, die oft durch eine fehlerhafte Eingabe entstehen, nach hinten gereiht werden.

[//]: # (\(siehe XXX für Details\))


Um z.B. alle Veranstaltungen im Zeitraum der letzten Weltraummission eines Space Shuttles abzufragen, könnte der folgende Filter verwendet werden:

```javascript
{
  "token": "YOUR_ACCESS_TOKEN",
  "filter": {
    "attribute": {    
      "schedule": {
        "in": {
          "min": "2011-07-10T15:07UTC",
          "max": "2011-07-19T06:28UTC"
        }
      }
    }
  }
}
```

### Geobasierte Filterung - **filter\[geo\]**

dataCycle wird in vielen Fällen verwendet, um geografisch verortete Inhalte zu verwalten. Um diese geografischen Eigenschaften auch bei der Filterung von Inhalten nutzen zu können, stehen spezielle Filter für das Einschränken von Inhalten auf Basis ihrer geografischen Lage zur Verfügung.

#### Bounding-Box - **filter\[geo\]\[in\]\[box\]**

Eine grundlegende Möglichkeit, um Inhalte auf Basis ihrer Position zu filtern, nutzt eine sogenannte _Bounding-Box_. Eine _Bounding-Box_ ist über vier Eckpunkte eines Rechtecks festgelegt, von denen der Eckpunkt im Süd–Westen und der Eckpunkt im Nord-Osten übergeben werden müssen. (Die beiden anderen Eckpunkte ergeben sich aus denen, die übergeben werden müssen.) Um Inhalte innerhalb einer passenden Bounding-Box für Österreich abzurufen, könnten die folgenden Filterparameter verwendet werden:

```javascript
{
  "token": "YOUR_ACCESS_TOKEN",
  "filter": {
    "geo": {
      "in": {
        "box": [9.53074836730957,46.37226867675781,17.160776138305664,49.020530700683594]
      }
    }
  }
}
```
