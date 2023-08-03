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

Die gelieferten Daten enthalten neben dem Namen (```skos:prefLabel```) und einige Meta-Daten (z.B. Erstellungs- und Änderungsdatum) auch einen Link, um die zu diesem Klassifizierungsbaum gehörigen Klassifizierungen abzufragen (```dc:hasConcept```).

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

Die ausgelieferten Klassifizierungen enthalten neben den Daten der Klassifizierung selbst auch Informationen über die hierarchische Struktur des Klassifizierungsbaums. Über das Attribute ```skos:broader``` ist die direkt übergeordnete Klassifizierung verfügbar, mit dem Attribut ```skos:ancestors``` kann der komplette Pfad innerhalb des Klassifizierungsbaums erstellt werden.

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
  ],
}
```

Über das Attribut ```dc:color``` kann der Farbwert als HEX, mit oder ohne Alpha-Kanal, für eine Klassifizierung inkludiert werden. Dieses Attribut wird standardmäßig nicht ausgeliefert.

```json
{
  "@id": "6d9fbb75-1365-4edb-b470-56f8626d3a66",
  "@type": "skos:Concept",
  "dc:color": "#000000FF"
}
```

Über das Attribut ```dc:icon``` kann die URL zu einem Icon für eine Klassifizierung inkludiert werden. Dieses Attribut wird standardmäßig nicht ausgeliefert.

```json
{
  "@id": "6d9fbb75-1365-4edb-b470-56f8626d3a66",
  "@type": "skos:Concept",
  "dc:icon": "https://url.zu.einem.icon"
}
```

## Facettensuche

Es kann im Context eines Inhalts-Endpunktes in Kombination mit einem Klassifizierungsbaums eine Facettierung angefordert werden.

#### HTTP-GET:

_/api/v4/endpoints/ENDPOINT_ID|ENDPOINT_SLUG/facets/CONCEPT_SCHEME_ID?token=YOUR_ACCESS_TOKEN_

#### HTTP-POST:

_/api/v4/endpoints/ENDPOINT_ID|ENDPOINT_SLUG/facets/CONCEPT_SCHEME_ID

```json
{
  "token": "YOUR_ACCESS_TOKEN"
}
```

Dabei wird bei jeder Klassifizierung die Anzahl der indirekt verknüpften Inhalte (Mappings und untergeordnete Klassifizierungen werden berücksichtigt) unter ```dc:thingCountWithSubtree```, sowie die Anzahl der direkt verknüpften Inhalte unter ```dc:thingCountWithoutSubtree``` ausgegeben.

Bei diesem Endpunkt werden verwendete ```filter``` auf die Inhalte direkt angewendet, verwendete ```sort```, ```fields``` und ```includes``` werden auf die Klassifizierungen angewendet.

Die übergebene ```language``` wird auf Inhalte und Klassifizierungen angewendet.

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
  ],
}
```

### Sortierung

Es gibt auch die Möglichkeit über diese beiden Attribute nach der Anzahl der verknüpften Inhalte zu [sortieren](/docs/api/contents#sortieren-von-inhalten):

* ```sort=+dc:thingCountWithSubtree``` (aufsteigend)
* ```sort=-dc:thingCountWithSubtree``` (absteigend)
* ```sort=+dc:thingCountWithoutSubtree``` (aufsteigend)
* ```sort=-dc:thingCountWithoutSubtree``` (absteigend)

<!--

## Filtern von Klassifizierungsbäumen und Klassifizierungen

Um den Zugriff auf die tatsächlich benötigten Klassifizierungsbäume und Klassifizierungen zu vereinfachen, bietet die Datenschnittstelle die Möglichkeit zum Einschränken der gelieferten Ergebnisse über unterschiedliche Filter. Einige dieser Filter sind sowohl für Klassifizierungsbäume als auch für Klassifizierungen verfügbar, andere Filter sind auf einen dieser beide Datentypen beschränkt.


### Attribute - **filter\[attribute\]**

-->
