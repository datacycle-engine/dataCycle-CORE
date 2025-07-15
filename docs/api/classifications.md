# Abfragen von Klassifizierungen über die Datenschnittstelle

Ein wesentlicher Baustein für die Verwendung der Datenschnittstelle von dataCycle sind Klassifizierungen. Über Klassifizierungen werden sämtliche Zuordnungen von Inhalten zu strukturierten Abstraktionen (z.B. Kategorien) sowie zu unstrukturierten Sammelbegriffen (z.B. Schlagworte oder Tags) abgebildet. Außerdem können Klassifizierungen für die Filterung von Inhalten verwendet werden ([Filtern von Inhalten mittels Klassifizierungen](/docs/api/contents#klassifizierungen-filter-classifications)).

Für die Nutzung im Rahmen eines Inhaltsfilters ist es in den meisten Fällen notwendig, die Klassifizierungen bereits vorab zum Aufbauen des gewünschten Filters zur Verfügung zu haben. Zu diesem Zweck können alle verfügbaren (und für die Datenschnittstelle freigegebenen) Klassifizierungsbäume und die zugehörigen Klassifizierungen über die Datenschnittstelle abgefragt werden. Alternativ dazu können die zu einem Klassifizierungsbaum gehörenden Klassifizierungen auch direkt abgerufen werden, wenn der Klassifizierungsbaum z.B. über eine vorherige Abfrage eines Inhalts bereits bekannt ist.

## Abfragen von Klassifizierungsbäumen

Alle Klassifizierungen in dataCycle sind in Form von Klassifizierungsbäumen organisiert. Um alle vorhandenen Klassifizierungsbäume abzufragen, kann der folgende Endpunkt verwendet werden:

#### HTTP-GET:

_/api/v4/concept_schemes?token=YOUR_ACCESS_TOKEN_

#### HTTP-POST:

_/api/v4/concept_schemes_

```json
{
  "token": "YOUR_ACCESS_TOKEN"
}
```

Die gelieferten Daten enthalten neben dem Namen (`skos:prefLabel`) und einige Meta-Daten (z.B. Erstellungs- und Änderungsdatum) auch einen Link, um die zu diesem Klassifizierungsbaum gehörigen Klassifizierungen abzufragen (`dc:hasConcept`).

```json
{
  "@graph": [
    {
      "@id": "c876e99d-81d4-435f-a7f4-a4f2f62c9db3",
      "@type": "skos:ConceptScheme",
      "skos:prefLabel": "Inhaltstypen",
      "dc:hasConcept": "/api/v4/concept_schemes/c876e99d-81d4-435f-a7f4-a4f2f62c9db3/concepts",
      "dct:created": "2020-05-30T19:22:00",
      "dct:modified": "2020-08-02T12:35:00"
    },
    {
      "@id": "1364702e-b39f-4c8b-ae2f-6ffd6acd12da",
      "@type": "skos:ConceptScheme",
      "skos:prefLabel": "Wochentage",
      "dc:hasConcept": "/api/v4/concept_schemes/1364702e-b39f-4c8b-ae2f-6ffd6acd12da/concepts",
      "dct:created": "2020-05-30T19:22:00",
      "dct:modified": "2020-05-30T19:22:00"
    },
    ...
  ]
}
```

## Abfragen von Klassifizierungen

Klassifizierungen müssen immer im Kontext des zugehörigen Klassifizierungsbaums abgefragt werden. Die URL zur Liste mit den Klassifizierungen kann entweder aus einer konkreten Klassifizierung eines Inhalts abgeleitet oder über die Liste aller Klassifizierungsbäume direkt abgefragt werden.

#### HTTP-GET:

_/api/v4/concept_schemes/1364702e-b39f-4c8b-ae2f-6ffd6acd12da/concepts?token=YOUR_ACCESS_TOKEN_

#### HTTP-POST:

_/api/v4/concept_schemes/1364702e-b39f-4c8b-ae2f-6ffd6acd12da/concepts_

```json
{
  "token": "YOUR_ACCESS_TOKEN"
}
```

Die ausgelieferten Klassifizierungen enthalten neben den Daten der Klassifizierung selbst auch Informationen über die hierarchische Struktur des Klassifizierungsbaums. Über das Attribute `skos:broader` ist die direkt übergeordnete Klassifizierung verfügbar, mit dem Attribut `skos:ancestors` kann der komplette Pfad innerhalb des Klassifizierungsbaums erstellt werden.

```json
{
  "@graph": [
    {
      "@id": "6d9fbb75-1365-4edb-b470-56f8626d3a66",
      "@type": "skos:Concept",
      "skos:prefLabel": "Klassische Musik",
      "skos:broader": {
        "@id": "a12a869d-892a-4224-861e-06492b7c63fa",
        "@type": "skos:Concept"
      },
      "skos:ancestors": [
        {
          "@id": "a12a869d-892a-4224-861e-06492b7c63fa",
          "@type": "skos:Concept"
        }
      ]
    },
    {
      "@id": "a12a869d-892a-4224-861e-06492b7c63fa",
      "@type": "skos:Concept",
      "skos:prefLabel": "Musik"
    },
    {
      "@id": "bb3eb7bd-5392-4e57-bec6-4c3654fcaaf5",
      "@type": "skos:Concept",
      "skos:prefLabel": "Oper",
      "skos:broader": {
        "@id": "6d9fbb75-1365-4edb-b470-56f8626d3a66",
        "@type": "skos:Concept"
      },
      "skos:ancestors": [
        {
          "@id": "6d9fbb75-1365-4edb-b470-56f8626d3a66",
          "@type": "skos:Concept"
        },
        {
          "@id": "a12a869d-892a-4224-861e-06492b7c63fa",
          "@type": "skos:Concept"
        }
      ]
    }
  ]
}
```

##### Attribut `dc:color`

Über das Attribut `dc:color` kann der Farbwert als HEX, mit oder ohne Alpha-Kanal, für eine Klassifizierung inkludiert werden. Dieses Attribut wird standardmäßig nicht ausgeliefert, kann aber über `include` oder `fields` angefordert werden.

```json
{
  "@id": "6d9fbb75-1365-4edb-b470-56f8626d3a66",
  "@type": "skos:Concept",
  "dc:color": "#000000FF"
}
```

##### Attribut `dc:icon`

Über das Attribut `dc:icon` kann die URL zu einem Icon für eine Klassifizierung inkludiert werden. Dieses Attribut wird standardmäßig nicht ausgeliefert, kann aber über `include` oder `fields` angefordert werden.

```json
{
  "@id": "6d9fbb75-1365-4edb-b470-56f8626d3a66",
  "@type": "skos:Concept",
  "dc:icon": "https://url.zu.einem.icon"
}
```

##### Attribut `geo`

Über das Attribut `geo` kann die Geometrie für eine Klassifizierung inkludiert werden. Dieses Attribut wird standardmäßig nicht ausgeliefert, kann aber über `include` oder `fields` angefordert werden.

```json
{
  "@id": "6d9fbb75-1365-4edb-b470-56f8626d3a66",
  "@type": "skos:Concept",
  "geo": {
    "@id": "3aaf756b-7034-4e09-84c1-18f2133f99ce",
    "@type": "GeoShape",
    "polygon": "MULTIPOLYGON (((6.534699…01 47.69134879624543)))"
  }
}
```

## Filtern und Sortieren von Klassifizierungen

Eine detaillierte Auflistung aller möglichen Filter und Sortierungen kann in der [Spezifikation](/docs/api/classifications/specification) nachgelesen werden.

#### Filtern von Klassifizierungen nach `skos:broader` und `skos:ancestors`

Es ist möglich die Ergebnismenge auf direkte Kinder bzw. Unterklassifizierungen von Klassifizierungen einzuschränken.

```jsonc
{
  "filter": {
    "attribute": {
      "skos:ancestors": {
        "in": [
          "4ec1c188-ccf0-4979-8f3d-5e03f1ca5078" // Administrative Einheit > Österreich
        ]
      },
      "skos:broader": {
        "in": [
          "null", // nur Top-Level Klassifizierungen
          "4ec1c188-ccf0-4979-8f3d-5e03f1ca5078" // Administrative Einheit > Österreich
        ]
      }
    }
  }
}
```

## Facettensuche

Es kann im Context eines Inhalts-Endpunktes in Kombination mit einem Klassifizierungsbaums eine Facettierung angefordert werden.

#### HTTP-GET:

_/api/v4/endpoints/ENDPOINT_ID|ENDPOINT_SLUG/facets/CONCEPT_SCHEME_ID?token=YOUR_ACCESS_TOKEN_

#### HTTP-POST:

\_/api/v4/endpoints/ENDPOINT_ID|ENDPOINT_SLUG/facets/CONCEPT_SCHEME_ID

```json
{
  "token": "YOUR_ACCESS_TOKEN"
}
```

Dabei wird bei jeder Klassifizierung die Anzahl der indirekt verknüpften Inhalte (Mappings und untergeordnete Klassifizierungen werden berücksichtigt) unter `dc:thingCountWithSubtree`, sowie die Anzahl der direkt verknüpften Inhalte unter `dc:thingCountWithoutSubtree` ausgegeben.

Bei diesem Endpunkt werden verwendete `filter` auf die Inhalte direkt angewendet, verwendete `sort`, `fields` und `includes` werden auf die Klassifizierungen angewendet.

Die übergebene `language` wird auf Inhalte und Klassifizierungen angewendet.

```json
{
  "@graph": [
    {
      "@id": "6d9fbb75-1365-4edb-b470-56f8626d3a66",
      "@type": "skos:Concept",
      "skos:prefLabel": "Klassische Musik",
      "skos:broader": {
        "@id": "a12a869d-892a-4224-861e-06492b7c63fa",
        "@type": "skos:Concept"
      },
      "skos:ancestors": [
        {
          "@id": "a12a869d-892a-4224-861e-06492b7c63fa",
          "@type": "skos:Concept"
        }
      ],
      "dc:thingCountWithSubtree": 55,
      "dc:thingCountWithoutSubtree": 25
    },
    {
      "@id": "a12a869d-892a-4224-861e-06492b7c63fa",
      "@type": "skos:Concept",
      "skos:prefLabel": "Musik"
    },
    {
      "@id": "bb3eb7bd-5392-4e57-bec6-4c3654fcaaf5",
      "@type": "skos:Concept",
      "skos:prefLabel": "Oper",
      "skos:broader": {
        "@id": "6d9fbb75-1365-4edb-b470-56f8626d3a66",
        "@type": "skos:Concept"
      },
      "skos:ancestors": [
        {
          "@id": "6d9fbb75-1365-4edb-b470-56f8626d3a66",
          "@type": "skos:Concept"
        },
        {
          "@id": "a12a869d-892a-4224-861e-06492b7c63fa",
          "@type": "skos:Concept"
        }
      ],
      "dc:thingCountWithSubtree": 11,
      "dc:thingCountWithoutSubtree": 0
    }
  ]
}
```

### Einschränkung der Ergebnismenge

Standardmäßig werden alle Klassifizierungen eines Klassifizierungsbaums zurückgegeben, egal welche Filter angewendet werden. Filter haben nur Einfluss auf die Counts (`dc:thingCountWithSubtree` und `dc:thingCountWithoutSubtree`).

Es gibt jedoch die Möglichkeit, die Ergebnismenge auf Ergebnisse zu beschränken, die eine Mindestanzahl an verknüpften Inhalten aufweisen (mit oder ohne Unterbaum). Das macht besonders bei sehr großen Klassifizierungsbäumen Sinn. Dazu können die Parameter `minCountWithSubtree` und `minCountWithoutSubtree` verwendet werden. Diese Parameter können auch in Kombination verwendet werden.

#### HTTP-GET:

\_/api/v4/endpoints/ENDPOINT_ID|ENDPOINT_SLUG/facets/CONCEPT_SCHEME_ID?token=YOUR_ACCESS_TOKEN&minCountWithSubtree=1

#### HTTP-POST:

\_/api/v4/endpoints/ENDPOINT_ID|ENDPOINT_SLUG/facets/CONCEPT_SCHEME_ID

```json
{
  "token": "YOUR_ACCESS_TOKEN",
  "minCountWithSubtree": 1
}
```

In diesem Beispiel werden nur Klassifizierungen zurückgegeben, die mindestens einen Inhalt direkt oder indirekt über einen Unterbaum verknüpft haben (with_subtree). Die Klassifizierungen, die keine verknüpften Inhalte haben, werden nicht zurückgegeben. Hinweis: `minCountWithSubtree` wird implizit immer auf den Wert von `minCountWithoutSubtree` gesetzt, wenn der Parameter nicht explizit gesetzt wird. Auch kann kann `minCountWithSubtree` nicht kleiner als `minCountWithoutSubtree` sein.

### Sortierung

Es gibt auch die Möglichkeit über diese beiden Attribute nach der Anzahl der verknüpften Inhalte zu [sortieren](/docs/api/contents#sortieren-von-inhalten):

- `sort=+dc:thingCountWithSubtree` (aufsteigend)
- `sort=-dc:thingCountWithSubtree` (absteigend)
- `sort=+dc:thingCountWithoutSubtree` (aufsteigend)
- `sort=-dc:thingCountWithoutSubtree` (absteigend)

<!--

## Filtern von Klassifizierungsbäumen und Klassifizierungen

Um den Zugriff auf die tatsächlich benötigten Klassifizierungsbäume und Klassifizierungen zu vereinfachen, bietet die Datenschnittstelle die Möglichkeit zum Einschränken der gelieferten Ergebnisse über unterschiedliche Filter. Einige dieser Filter sind sowohl für Klassifizierungsbäume als auch für Klassifizierungen verfügbar, andere Filter sind auf einen dieser beide Datentypen beschränkt.


### Attribute - **filter\[attribute\]**

-->
