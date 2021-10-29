# Abfragen von Inhalten über die Datenschnittstelle

In dataCycle gibt es zwei Möglichkeiten, wie Inhalte über die Datenschnittstelle verfügbar gemacht werden können. Für eine von Hand ausgewählte Selektion von Inhalten können (statische) Inhaltssammlungen genutzt werden. Sollen Inhalte auf Basis von unterschiedlichen Filterkriterien automatisch ausgewählt werden, können gespeicherte Suchen bzw. "dynamische" Inhaltssammlungen verwendet werden. Über die Datenschnittstelle werden statische und dynamische Inhaltssammlungen über ein einheitliches URL-Schema (_**/api/v4/endpoints/ENDPOINT_ID**_) bereitgestellt. Die konkrete URL kann über das User-Interface direkt bei der jeweiligen Inhaltssammlung bzw. bei der gespeicherten Suche in die Zwischenablage übernommen werden.


## Filtern von Inhalten

Häufig ist es so, dass neben der Einschränkung von Inhalten im Zuge der Erstellung eines Datenendpunkts auch eine nachträgliche Filterung direkt beim Abrufen der Inhalte wünschenswert bzw. notwendig ist. Bei dataCycle stehen deshalb unterschiedliche Filter zur Verfügung, die direkt über die API genutzt werden können. Um unterschiedliche Anwendungsfälle möglichst gut abdecken zu können, stehen unterschiedliche Typen von Filtern zu Verfügung. Der grundsätzliche Aufbau der unterschiedlichen Filtertypen ist dabei aber immer sehr ähnlich: Alle Filter beginnen mit ```filter[TYPE]```. Je nach ausgewähltem Filtertyp unterscheidet sich die restliche Filterkonfiguration und ist auf den jeweiligen Filter abgestimmt.

Die API unterstützt das Abfragen und auch das Filtern von Inhalten sowohl über **HTTP-GET** als auch über **HTTP-POST**, im Falle einer POST-Abfrage müssen die Parameter im **JSON**-Format an dataCycle übermittelt werden. Die folgenden Abfragen sind damit also äquivalent und liefern auch exakt die gleichen Inhalte aus:

#### HTTP-GET:

_/api/v4/endpoints/ffa78ef5-6e6a-47fa-a817-a771390d48dc?token=YOUR_ACCESS_TOKEN&filter[classifications][in][withSubtree][]=3b9b4787-99e5-47c1-8d09-db65c1db43cc_

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
      "dct:created": {
        "in": {
          "min": "2020-03-16",
          "max": "2020-05-14"
        },
        "notIn": {
          "min": "2020-04-06",
          "max": "2020-04-13"
        }          
      }
    },
    "schedule": {
      "in": {
        "min": "2020-06-21",
        "max": "2020-09-20"
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

Alternativ kann diese Anfrage auch über **HTTP-GET** umgesetzt werden:

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


Um die Flexibilität des Klassifizierungsfilters noch weiter zu steigern, können die einzelnen Filterbausteine beliebig kombiniert werden, um eine maximale Flexibilität zu erlauben. Außerdem ist es möglich die übergebenen Klassifizierungen sowohl mit **UND** als auch mit einem **ODER** zu verknüpfen. Für eine **UND**-Verknüpfung müssen die Klassifizierungen als separate Elemente eines Arrays übergeben werden, für eine **ODER**-Verknüpfung in Form einer kommagetrennten Liste innerhalb eines einzelnen Strings. Um beispielsweise nach Gallerien oder Museen zu suchen, die barrierefrei zugänglich sind und die derzeit keinen Schwerpunkt auf moderne Kunst gesetzt haben, könnte die folgende Abfrage verwendet werden:

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

Derzeit können unterschiedliche Arten von numerischen Attributen, wie z.B. das Erstellungsdatum, ein Veranstaltungstermin oder die Breite eines Bildes, für die Filterung von Inhalten herangezogen werden. Da all diese numerischen Attribute als skalare Werte interpretiert werden können, stehen für alle Attribute die gleichen Filtermöglichkeiten zur Verfügung. Im Prinzip kann man sich diese Attribute immer als Wert auf einer Zahlengerade vorstellen. Möchte man nun eine Filterung durchführen, kann der relevante Bereich auf dieser Zahlengerade durch einen entsprechenden Filter eingeschränkt werden. Unterstützt werden an dieser Stelle sowohl beschränkte Intervalle mit einer unteren (**filter\[attribute\]\[*ATTRIBUTE_NAME*\]\[in\]\[min\]**) und einer oberen Schranke ((**filter\[attribute\]\[*ATTRIBUTE_NAME*\]\[in\]\[max\]**)) als auch einseitig unbeschränkte Intervalle mit entweder nur einer oberen oder nur einer unteren Schranke. Außerdem ist es möglich, das Intervall zu invertieren, sprich den Wertebereich außerhalb des angegebenen Intervalls auszuwählen (**filter\[attribute\]\[*ATTRIBUTE_NAME*\]\[notIn\]\[min\]** bzw. **filter\[attribute\]\[*ATTRIBUTE_NAME*\]\[notIn\]\[max\]**). Die übergebenen Intervalle werden von dataCycle immer als geschlossene Intervalle interpretiert, das heißt, die angegebenen Intervallgrenzen werden bei den damit festgelegten Wertebereichen eingeschlossen.
Um beispielsweise alle Veranstaltungen im Herbst und im Winter außer den Veranstaltungen zwischen den Weihnachtsfeiertagen auszuwählen, könnte folgende Filterkonfiguration genutzt werden:

```javascript
{
  "token": "YOUR_ACCESS_TOKEN",
  "filter": {
    "attribute": {
      "eventSchedule": {
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

#### Aktualisierungen - **filter\[attribute\]\[dct:created|dct:modified|deletedAt\]**

Für einige Anwendungsfälle kann es hilfreich sein, herausfinden zu können, welche Datensätze innerhalb einer vorgegeben Zeitspanne erstellt, geändert oder gelöscht worden sind. Zu diesem Zweck können bei allen API-Endpunkten, die sich aus statischen bzw. dynamischen Inhaltssammlungen ergeben, spezielle _Attribut-Filter_ genutzt werden. Dadurch kann die Anzahl der Datensätze, die geladen werden muss, erheblich reduziert werden. Außerdem muss die Prüfung, ob es seit dem letzten Update neue Änderungen gegeben hat, nicht client-seitig durchgeführt werden, wodurch die auf dataCycle aufbauenden Anwendungen noch einmal deutlich entlastet werden können. Für diese Art der Filterung werden die folgenden Attribute unterstützt:

* **dct:created**
* **dct:modified**
* **dct:deleted** (_ACHTUNG: Dieser Filter steht nur über den speziellen Endpunkt [/api/v4/things/deleted](/api/v4/things/deleted) zur Verfügung!_)

Bei der Verwendung von Zeitpunkten im Rahmen eines Filterkriteriums müssen die Zeitpunkte entsprechend den Vorgaben von [RFC 3339](https://tools.ietf.org/html/rfc3339) übergeben werden, damit sie von dataCycle korrekt interpretiert werden können.

Sollen beispielsweise alle Inhalte ermittelt werden, die am "Marty-McFly-Day" erstellt worden sind, könnte der Filter folgendermaßen übergeben werden:

```javascript
{
  "token": "YOUR_ACCESS_TOKEN",
  "filter": {
    "attribute": {
      "dct:created": {
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


#### Termine - **filter\[attribute\]\[eventSchedule\]**

Sind Veranstaltungen im Datenbestand einer dataCycle-Instanz vorhanden, ist es in der Regel notwendig, diese Veranstaltungen auf Basis des Veranstaltungstermins zu filtern. Da in dataCycle wiederkehrende Veranstaltungstermine in Form von Regelsätzen hinterlegt werden können und nicht als Einzeltermine erfasst werden müssen, gibt es einen speziellen _Attribut-Filter_ für diesen Anwendungsfall. Es kann zwar auch bei diesem Filter ein bzw. mehrere Intervalle übergeben werden, im Gegensatz zu einfachen Zeitpunkten wird bei der Verwendung dieses Filters aber auch eine spezielle Sortierung, die spezifisch auf Termine abgestimmt worden ist, verwendet. Dabei werden Veranstaltungen nach dem ersten Termin im angegeben Zeitraum sortiert, wobei sehr lange dauernde Veranstaltungen, die oft durch eine fehlerhafte Eingabe entstehen, nach hinten gereiht werden.

[//]: # (\(siehe XXX für Details\))


Um z.B. alle Veranstaltungen im Zeitraum der letzten Weltraummission eines Space Shuttles abzufragen, könnte der folgende Filter verwendet werden:

```javascript
{
  "token": "YOUR_ACCESS_TOKEN",
  "filter": {
    "attribute": {    
      "eventSchedule": {
        "in": {
          "min": "2011-07-10",
          "max": "2011-07-19"
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


#### Umkreissuche - **filter\[geo\]\[in\]\[perimeter\]**

In einigen Anwendungsfällen ist es wünschenswert, Inhalte in einem definierten Umkreis zu suchen. Genau dafür kann in dataCycle eine sogenannte _Umkreissuche_ genutzt werden. Dieser Filter erwartet sich die folgenden drei Werte in genau dieser Reihenfolge:

* Längengrad
* Breitengrad
* Radius (in m)

Um Inhalte im Umkreis von 50 km um den Großglockner abzufragen, kann beispielsweise die folgende Filterkonfiguration genutzt werden:

```javascript
{
  "token": "YOUR_ACCESS_TOKEN",
  "filter": {
    "geo": {
      "in": {
        "perimeter": [12.69390,47.07453,50000] // Längengrad, Breitengrad, Radius (in m)
      }
    }
  }
}
```


#### Geo-Shapes - **filter\[geo\]\[in\]\[shapes\]**

Neben einer Filterung auf Basis einer Bounding-Box bzw. eines Umkreises bietet dataCycle auch die Möglichkeit, beliebige andere Geo-Shapes für eine Einschränkung der ausgelieferten Inhalte zu verwenden. Diese Geo-Shapes sind innerhalb von dataCycle als spezielle Klassifizierungen abgebildet, die z.B. Regions-, Gemeinde- oder Bezirksgrenzen enthalten können. Bei der Verwendung dieses Filters müssen dementsprechend auch die jeweiligen IDs der Klassifizierungen, bei denen die gewünschten Geo-Shapes hinterlegt sind, übergeben werden. Eine Abfrage für alle Orte innerhalb der Landeshauptstädte von Österreich könnte z.B. folgendermaßen realisiert werden:

```javascript
{
  "token": "YOUR_ACCESS_TOKEN",
  "filter": {
    "geo": {
      "in": {
        "shapes": [
          "f49c4cc4-229a-4421-bf7f-9e1919b93482", // Wien
          "13e7efe2-2c2a-49a8-a5d9-44f3c279716a", // Sankt Pölten
          "2a13f3d3-914e-4a73-a7e9-32fe76ab7e2a", // Eisenstadt
          "044b50ba-28f6-4e9a-9fc3-7f13ac4edb57", // Graz
          "e0cbd09e-c532-4663-b731-5fd99049307a", // Klagenfurt
          "01f13679-cded-4307-af50-4d0184674ed9", // Linz
          "b8d838c0-221d-4d74-b73a-df52df5b3c9c", // Salzburg
          "d7108f09-7467-4699-a4fa-51b4ed0bab29", // Innsbruck
          "f0e38258-c919-4676-ab1c-3729bea85f8e"  // Bregenz
        ]
      }
    }
  }
}
```


### Graphbasierte Filterung - **filter\[linked\]\[RELATION\]\[...\]**

Bei der Filterung von Inhalten auf Basis von Klassifizierungen, Attributen oder der geografischen Lage erfolgt die Filterung immer auf Basis von Eigenschaften des jeweiligen Inhalts. In einigen Fällen ist es aber notwendig, Inhalte auf Basis von anderen, verknüpften Inhalten einzuschränken. Ein konkreter Anwendungsfall dafür wäre etwa die Filterung von Veranstaltungen auf Basis der geografischen Lage des Veranstaltungsortes. Die Veranstaltung ist dabei über die Relation **location** mit dem Veranstaltungsort verknüpft. Um beispielsweise Veranstaltungen rund um Schloss Rotenturm zu filtern, kann der folgende Filter verwendet werden:

```javascript
{
  "token": "YOUR_ACCESS_TOKEN",
  "filter": {
    "linked": {
      "location": { // Name der Relation
        "geo": {
          "in": {
            "perimeter": [16.2448,47.2509,3000] // Längengrad, Breitengrad, Radius (in m)
          }
        }
      }
    }
  }
}
```

Der Filter besteht dabei aus einem äußeren und einem inneren Teil. Im inneren Teil können alle Filter verwendet werden, die sich direkt auf einen Inhalt beziehen, es können also alle geobasierten, attributbasierten und klassifizierungsbasierten Filter verwendet werden. Auch eine Kombination von verschiedenen Filtern ist möglich.

Im äußeren Teil wird festgelegt, wie die Inhalte aus dem inneren Filter mit den eigentlich abgefragten Inhalten verknüpft sein müssen. Die Art der Verknüpfung wird dabei über den Namen der Relation festgelegt, also z.B. *filter\[linked\]\[__location__\]\[...\]*.

#### Filterung auf Basis von Verknüpfungen mit einzelnen, ausgewählten Inhalten - **filter\[linked\]\[RELATION\]\[contentId\]**

Oft kann es sinnvoll sein, verknüpfte Inhalte direkt auswählen bzw. ausschließen zu können. Damit können z.B. Veranstaltung ausgewählt werden, die an einem bestimmten Veranstaltungsort stattfinden:

```javascript
{
  "token": "YOUR_ACCESS_TOKEN",
  "filter": {
    "linked": {
      "location": { // Name der Relation
        "contentId": {
          "in": [
            "d419e7bf-1dc6-4689-8e2b-b6e689f81f73" // Großer Musikvereinssaal
          ]
        }
      }
    }
  }
}
```

Analog dazu können über eine ausschließende Filterung beispielsweise Bilder ausgewählt werden, die **nicht** von einer bestimmten Gruppe von Fotografen gemacht worden sind:

```javascript
{
  "token": "YOUR_ACCESS_TOKEN",
  "filter": {
    "linked": {
      "author": { // Name der Relation
        "contentId": {
          "notIn": [
            "9f06a2a1-3413-4d8c-be5d-ebeecdf0b3a6", // Alexandra Baader
            "98d80f8b-aa85-4437-ad73-e19f30af6aab" // Yannick Steinhauer
          ]
        }
      }
    }
  }
}
```


## Fusionieren von Ergebnissen von unterschiedlichen Filtern

Die bisher vorgestellten Filter ergeben, wenn sie kombiniert werden, immer eine UND-Verknüpfung der unterschiedlichen Filterkriterien. Oft ist es aber wünschenswert, unterschiedliche Filterkriterien über ein logisches ODER miteinander zu verknüpfen. Aus diesem Grund bietet die Datenschnittstelle von dataCycle einen sogenannten *union*-Filter. Damit können z.B. Veranstaltungen kombiniert werden, die an unterschiedlichen, nicht zusammenhängenden Tagen stattfinden:

```javascript
{
  "token": "YOUR_ACCESS_TOKEN",
  "filter": {
    "union": [
      {
        "attribute": {
          "eventSchedule": {
            "in": {
              "min": "2021-03-01",
              "max": "2021-03-01"
            }
          }      
        }
      }, {
        "attribute": {
          "eventSchedule": {
            "in": {
              "min": "2021-03-21",
              "max": "2021-03-21"
            }
          }      
        }
      }
    ]
  }
}
```

Innerhalb des *union*-Filters können alle anderen, bereits bekannten Filter verwendet werden. Wichtig dabei ist, sich im Vorfeld über die möglichen Performance-Implikationen im Klaren zu sein. Da alle Teile eines *union*-Filters unabhängig voneinander verarbeitet werden müssen, um eine maximale Flexibilität zu erreichen, können damit unter Umständen sehr komplexe und damit langsame Filterkombinationen erzeugt werden.


## Sortieren von Inhalten

Neben der Filterung von Inhalten ist es über die Datenschnittstelle von dataCycle auch möglich, Inhalte nach unterschiedlichen Kriterien zu sortieren. Es gibt dabei zwei grundsätzlich unterschiedliche Arten von Sortierungen: implizite (automatische) Sortierungen und explizite (benutzerdefinierte) Sortierungen. Während explizite Sortierungen manuell angewendet werden müssen, werden implizite Sortierungen automatisch verwendet, sobald Inhalte auf eine bestimmte Art und Weise gefiltert werden. Eine implizite Sortierung ergibt sich also auf Basis der verwendeten Filter und kann nicht manuell ausgewählt werden.


### Implizites (automatisches) Sortieren von Inhalten

Je nachdem, welche Filter beim Abfragen von Inhalten verwendet werden, kann in speziellen Fällen automatisch eine passende Sortierung angewendet werden. Sollen beispielsweise Veranstaltungen für einen bestimmten Zeitraum abgefragt werden, können diese auf Basis des Veranstaltungstermins sortiert werden. Ist eine der in weiterer Folge beschriebenen Sortierungen anwendbar, wird diese automatisch verwendet. Eine manuelle Auswahl der impliziten Sortiermethoden ist nicht möglich. Der Grund dafür ist, dass es sich dabei um Sortierungen handelt, die nur in einem sehr speziellen Kontext sinnvoll angewendet werden können und einen oder mehrere Referenzwerte (z.B. einen Zeitraum) benötigen.


#### Relevanzbasierte Sortierung

Bei der Volltextsuche werden verschiedene Attribute, mit unterschiedlichen Gewichtungen berücksichtigt. Auf Basis der gefundenen Treffer und der jeweiligen Gewichtungen wird eine relevanzbasierte Sortierung durchgeführt. Neben den offensichtlichen Text-Attributen, werden auch Klassifizierungen bei der Volltextsuche berücksichtigt. Außerdem werden alle Attribute und nicht nur diejenigen, die über den Parameter ```fields``` angefragt werden, sowohl bei der Volltextsuche als auch bei der relevanzbasierten Sortierung berücksichtigt. Diese beiden Punkte sollten immer im Hinterkopf behalten werden, falls eine Sortierung auf den ersten Blick nicht passend erscheint.

#### Terminbasierte Sortierung

Werden Inhalte auf Basis von Terminen gefiltert (z.B. bei Veranstaltungen), erscheint eine Sortierung auf Basis des Startzeitpunktes eines Termins als optimal. Diese Art der Sortierung führt allerdings dazu, dass Termine mit einer sehr langen Dauer (z.B. Wochen oder Monate) und einem Startzeitpunkt in der Vergangenheit nach vorne gereiht werden. Dieses Verhalt ist im Regelfall nicht wünschenswert! Deshalb berücksichtigt die terminbasierte Sortierung neben dem Startzeitpunkt auch das Ende und in gewisser Weise auch die Dauer eines Termins.


### Explizites (benutzerdefiniertes) Sortieren von Inhalten

Neben den automatisch angewendeten impliziten Sortierungen, gibt es die Möglichkeit direkt beim Abrufen der Inhalte über die API, eine explizite, benutzerdefinierte Sortierung festzulegen. Soll eine solche explizite Sortierung verwendet werden, weil z.B. für die abgefragten Inhalte keine der verfügbaren implizite Sortierungen angewendet werden kann oder weil die implizite Sortierung nicht das gewünschte Ergebnis liefert, muss diese über den Parameter ``sort`` übergeben werden. Inhalte können dabei sowohl auf- als auch absteigend sortiert werden. Die Richtung kann über ein Voranstellen eins **Plus-** bzw. **Minuszeichens** festgelegt werden, wobei die aufsteigende Sortierung (+) als Standard verwendet wird. Eine aufsteigende Sortierung auf Basis des Erstellungsdatums kann bei einer Abfrage über **HTTP-POST** also folgendermaßen angewendet werden:

```javascript
{
  "token": "YOUR_ACCESS_TOKEN",
  "sort": "dct:created"
}
```

Alternativ kann die Sortierung auch bei einer Abfrage über **HTTP-GET** angewendet werden:

_/api/v4/endpoints/ffa78ef5-6e6a-47fa-a817-a771390d48dc?token=YOUR_ACCESS_TOKEN,sort=dct:created_

Die Attribute, die für die Filterung nutzbar sind, können pro Installation individuell eingeschränkt werden. Prinzipiell stehen aber die folgenden Attribute zur Verfügung:

* **dct:created**
* **dct:modified**
* **name**


### Zufallssortierung

Neben den beiden bereits beschriebenen Möglichkeiten zum Sortieren von Inhalten, gibt es auch eine Möglichkeit um Inhalte in zufälliger Reihenfolge abzufragen. Ein möglicher Anwendungsfall dafür wäre beispielsweise, wenn aus einer großen Anzahl von Inhalten bei jedem Zugriff fünf zufällige Inhalte ausgewählt werden sollen. Über die Datenschnittstelle kann diese Zufallsauswahl folgendermaßen erreicht werden:

```javascript
{
  "token": "YOUR_ACCESS_TOKEN",
  "sort": "random",
  "page": {
    "size": 5
  }
}
```

***ACHTUNG: Der Zufallsgenerator wird bei jeder Abfrage zurückgesetzt! Das heißt, dass bei einer Abfrage über mehrere Seiten nicht sichergestellt ist, dass keine Inhalte doppelt ausgeliefert werden. Um sicherzugehen, dass jeder Inhalt nur genau einmal ausgeliefert wird, sollte nur eine Seite mit einer passenden Seitengröße abgefragt werden.***
