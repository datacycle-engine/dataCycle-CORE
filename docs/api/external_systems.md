# Externe Systeme

Importierte Inhalte tragen eine Referenz auf das externe System, aus dem sie stammen (ihre primäre Quelle, `things.external_source_id`). Über die Datenschnittstelle kann im Context eines Inhalts-Endpunktes eine Facettierung nach diesen externen Systemen ("importiert von") angefordert werden.

## Facettensuche nach externem System

Liefert für den Ergebnissatz eines Endpunktes je externem System einen Eintrag mit der Anzahl der Inhalte, die aus diesem System importiert wurden. Es wird ausschließlich die primäre Quelle (`external_source_id`) berücksichtigt; Inhalte ohne primäre Quelle werden nicht gezählt.

#### HTTP-GET:

_/api/v4/endpoints/ENDPOINT_ID|ENDPOINT_SLUG/facets/externalSystems?token=YOUR_ACCESS_TOKEN_

#### HTTP-POST:

\_/api/v4/endpoints/ENDPOINT_ID|ENDPOINT_SLUG/facets/externalSystems

```json
{
  "token": "YOUR_ACCESS_TOKEN"
}
```

Verwendete `filter` werden – wie bei der [Facettensuche nach Klassifizierungen](/docs/api/classifications#facettensuche) – auf die Inhalte angewendet und beeinflussen so die Counts. Die übergebene `language` steuert die Sprache für die Berechnung der Inhalts-Counts.

Die externen Systeme werden absteigend nach der Anzahl der Inhalte (`dc:thingCount`) und bei gleicher Anzahl alphabetisch nach `name` sortiert ausgegeben. Das Attribut `@id` enthält den Identifier des externen Systems.

```json
{
  "@context": {
    // ...
  },
  "@graph": [
    {
      "@id": "feratel",
      "@type": "dc:ExternalSystem",
      "name": "Feratel Deskline",
      "dc:thingCount": 1024
    },
    {
      "@id": "outdooractive",
      "@type": "dc:ExternalSystem",
      "name": "Outdooractive",
      "dc:thingCount": 87
    }
  ],
  "meta": {
    "total": 2
  }
}
```

### Einschränkung der Ergebnismenge

Standardmäßig werden alle externen Systeme zurückgegeben, aus denen mindestens ein Inhalt des Ergebnissatzes importiert wurde. Mit dem Parameter `minCount` kann die Ergebnismenge auf externe Systeme beschränkt werden, die mindestens die angegebene Anzahl an Inhalten aufweisen. Das ist besonders bei sehr vielen externen Systemen sinnvoll.

#### HTTP-GET:

\_/api/v4/endpoints/ENDPOINT_ID|ENDPOINT_SLUG/facets/externalSystems?token=YOUR_ACCESS_TOKEN&minCount=100

#### HTTP-POST:

\_/api/v4/endpoints/ENDPOINT_ID|ENDPOINT_SLUG/facets/externalSystems

```json
{
  "token": "YOUR_ACCESS_TOKEN",
  "minCount": 100
}
```

In diesem Beispiel werden nur externe Systeme zurückgegeben, aus denen mindestens 100 Inhalte des Ergebnissatzes importiert wurden.

## Filtern von Inhalten nach externem System - **filter\[externalSystem\]**

Inhalte können auch direkt nach ihrer primären Quelle gefiltert werden (siehe auch [Filtern von Inhalten](/docs/api/contents#filtern-von-inhalten)). Als Werte können sowohl der Identifier (`@id` aus der Facettensuche) als auch die UUID eines externen Systems verwendet werden.

#### filter\[externalSystem\]\[in\]\[\]:

Liefert nur Inhalte, die aus einem der angegebenen externen Systeme importiert wurden.

_/api/v4/endpoints/ENDPOINT_ID|ENDPOINT_SLUG?token=YOUR_ACCESS_TOKEN&filter[externalSystem][in][]=feratel_

#### filter\[externalSystem\]\[notIn\]\[\]:

Liefert nur Inhalte, die **nicht** aus einem der angegebenen externen Systeme importiert wurden (inklusive Inhalte ohne primäre Quelle).

```json
{
  "token": "YOUR_ACCESS_TOKEN",
  "filter": {
    "externalSystem": {
      "notIn": ["feratel"]
    }
  }
}
```
