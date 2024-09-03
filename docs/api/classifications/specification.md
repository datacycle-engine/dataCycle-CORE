# Klassifizierung (concept) Spezifikation
```json
{
  "fields": "String",
  "filter": {
    "attribute": {
      "dct:modified": {
        "in": {
          "min": "Date|DateTime",
          "max": "Date|DateTime"
        },
        "notIn": {
          "min": "Date|DateTime",
          "max": "Date|DateTime"
        }
      },
      "dct:created": {
        "in": {
          "min": "Date|DateTime",
          "max": "Date|DateTime"
        },
        "notIn": {
          "min": "Date|DateTime",
          "max": "Date|DateTime"
        }
      },
      "dct:deleted": {
        "in": {
          "min": "Date|DateTime",
          "max": "Date|DateTime"
        },
        "notIn": {
          "min": "Date|DateTime",
          "max": "Date|DateTime"
        }
      },
      "skos:broader": {
        "in": [
          "null",
          "UUID"
        ],
        "notIn": [
          "null",
          "UUID"
        ]
      },
      "skos:ancestors": {
        "in": [
          "UUID"
        ],
        "notIn": [
          "UUID"
        ]
      }
    },
    "search": "String",
    "q": "String"
  },
  "language": "String: de",
  "include": "String",
  "page": {
    "size": "Integer: 25",
    "number": "Integer: 1",
    "offset": "Integer: 0",
    "limit": "Integer: 0",
    "count": "Integer: 1"
  },
  "section": {
    "@graph": "Integer [1,0]: 1",
    "@context": "Integer [1,0]: 1",
    "meta": "Integer [1,0]: 1",
    "links": "Integer [1,0]: 1"
  },
  "sort": "String ?[+,-] (dct:modified,dct:created): dct:modified",
  "token": "String"
}
```
