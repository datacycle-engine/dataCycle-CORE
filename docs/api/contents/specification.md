# Inhalt (content) Spezifikation

```json
{
  "apiSubversion": "String",
  "fields": "String",
  "classification_trees": "[UUID]",
  "filter": {
    "contentId": {
      "in": "[UUID]",
      "notIn": "[UUID]"
    },
    "endpointId": {
      "in": "[UUID]",
      "notIn": "[UUID]"
    },
    "filterId": {
      "in": "[UUID]",
      "notIn": "[UUID]"
    },
    "watchListId": {
      "in": "[UUID]",
      "notIn": "[UUID]"
    },
    "classificationTreeId": {
      "in": "[UUID]",
      "notIn": "[UUID]"
    },
    "attribute": {
      "{attributeName}": {
        "in": {
          "max": "Integer|Float|Date|DateTime",
          "min": "Integer|Float|Date|DateTime",
          "equals": "Integer|Float|String",
          "like": "String",
          "bool": "Boolean"
        },
        "notIn": {
          "max": "Integer|Float|Date|DateTime",
          "min": "Integer|Float|Date|DateTime",
          "equals": "Integer|Float|String",
          "like": "String",
          "bool": "Boolean"
        }
      }
    },
    "schedule": {
      "in": {
        "min": "Date|DateTime",
        "max": "Date|DateTime"
      }
    },
    "classifications|dc:classification": {
      "in": {
        "withSubtree": "[UUID]",
        "withoutSubtree": "[UUID]"
      },
      "notIn": {
        "withSubtree": "[UUID]",
        "withoutSubtree": "[UUID]"
      }
    },
    "geo": {
      "in": {
        "box": [
          "swLon",
          "swLat",
          "neLon",
          "neLat"
        ],
        "perimeter": [
          "lon",
          "lat",
          "distance"
        ],
        "shapes": "[UUID]",
      },
      "notIn": {
        "box": [
          "swLon",
          "swLat",
          "neLon",
          "neLat"
        ],
        "perimeter": [
          "lon",
          "lat",
          "distance"
        ],
        "shapes": "[UUID]",
      },
      "withGeometry": "Boolean"
    },
    "creator": {
      "in": "[UUID]",
      "notIn": "[UUID]"
    },
    "search": "String",
    "q": "String",
    "linked": {
      "{attributeName(,attributeName)}": {
        "contentId": {
          "in": "[UUID]",
          "notIn": "[UUID]"
        },
        "endpointId": {
          "in": "[UUID]",
          "notIn": "[UUID]"
        },
        "filterId": {
          "in": "[UUID]",
          "notIn": "[UUID]"
        },
        "watchListId": {
          "in": "[UUID]",
          "notIn": "[UUID]"
        },
        "classificationTreeId": {
          "in": "[UUID]",
          "notIn": "[UUID]"
        },
        "attribute": {
          "{attributeName}": {
            "in": {
              "max": "Integer|Float|Date|DateTime",
              "min": "Integer|Float|Date|DateTime",
              "equals": "String",
              "like": "String",
              "bool": "Boolean"
            },
            "notIn": {
              "max": "Integer|Float|Date|DateTime",
              "min": "Integer|Float|Date|DateTime",
              "equals": "String",
              "like": "String",
              "bool": "Boolean"
            }
          }
        },
        "classifications|dc:classification": {
          "in": {
            "withSubtree": "[UUID]",
            "withoutSubtree": "[UUID]"
          },
          "notIn": {
            "withSubtree": "[UUID]",
            "withoutSubtree": "[UUID]"
          }
        },
        "geo": {
          "in": {
            "box": [
              "swLon",
              "swLat",
              "neLon",
              "neLat"
            ],
            "perimeter": [
              "lon",
              "lat",
              "distance"
            ],
            "shapes": "[UUID]",
          },
          "notIn": {
            "box": [
              "swLon",
              "swLat",
              "neLon",
              "neLat"
            ],
            "perimeter": [
              "lon",
              "lat",
              "distance"
            ],
            "shapes": "[UUID]",
          },
          "withGeometry": "Boolean"
        },
        "search": "String",
        "q": "String"
      }
    },
    "union": [
      {
        "contentId": {
          "in": "[UUID]",
          "notIn": "[UUID]"
        },
        "endpointId": {
          "in": "[UUID]",
          "notIn": "[UUID]"
        },
        "filterId": {
          "in": "[UUID]",
          "notIn": "[UUID]"
        },
        "watchListId": {
          "in": "[UUID]",
          "notIn": "[UUID]"
        },
        "classificationTreeId": {
          "in": "[UUID]",
          "notIn": "[UUID]"
        },
        "attribute": {
          "{attributeName}": {
            "in": {
              "max": "Integer|Float|Date|DateTime",
              "min": "Integer|Float|Date|DateTime",
              "equals": "String",
              "like": "String",
              "bool": "Boolean"
            },
            "notIn": {
              "max": "Integer|Float|Date|DateTime",
              "min": "Integer|Float|Date|DateTime",
              "equals": "String",
              "like": "String",
              "bool": "Boolean"
            }
          }
        },
        "classifications|dc:classification": {
          "in": {
            "withSubtree": "[UUID]",
            "withoutSubtree": "[UUID]"
          },
          "notIn": {
            "withSubtree": "[UUID]",
            "withoutSubtree": "[UUID]"
          }
        },
        "geo": {
          "in": {
            "box": [
              "swLon",
              "swLat",
              "neLon",
              "neLat"
            ],
            "perimeter": [
              "lon",
              "lat",
              "distance"
            ],
            "shapes": "[UUID]"
          },
          "notIn": {
            "box": [
              "swLon",
              "swLat",
              "neLon",
              "neLat"
            ],
            "perimeter": [
              "lon",
              "lat",
              "distance"
            ],
            "shapes": "[UUID]"
          },
          "withGeometry": "Boolean"
        },
        "search": "String",
        "q": "String",
        "linked": {
          "{attributeName(,attributeName)}": {
            "contentId": {
              "in": "[UUID]",
              "notIn": "[UUID]"
            },
            "endpointId": {
              "in": "[UUID]",
              "notIn": "[UUID]"
            },
            "filterId": {
              "in": "[UUID]",
              "notIn": "[UUID]"
            },
            "watchListId": {
              "in": "[UUID]",
              "notIn": "[UUID]"
            },
            "classificationTreeId": {
              "in": "[UUID]",
              "notIn": "[UUID]"
            },
            "attribute": {
              "{attributeName}": {
                "in": {
                  "max": "Integer|Float|Date|DateTime",
                  "min": "Integer|Float|Date|DateTime",
                  "equals": "String",
                  "like": "String",
                  "bool": "Boolean"
                },
                "notIn": {
                  "max": "Integer|Float|Date|DateTime",
                  "min": "Integer|Float|Date|DateTime",
                  "equals": "String",
                  "like": "String",
                  "bool": "Boolean"
                }
              }
            },
            "classifications|dc:classification": {
              "in": {
                "withSubtree": "[UUID]",
                "withoutSubtree": "[UUID]"
              },
              "notIn": {
                "withSubtree": "[UUID]",
                "withoutSubtree": "[UUID]"
              }
            },
            "geo": {
              "in": {
                "box": [
                  "swLon",
                  "swLat",
                  "neLon",
                  "neLat"
                ],
                "perimeter": [
                  "lon",
                  "lat",
                  "distance"
                ],
                "shapes": "[UUID]"
              },
              "notIn": {
                "box": [
                  "swLon",
                  "swLat",
                  "neLon",
                  "neLat"
                ],
                "perimeter": [
                  "lon",
                  "lat",
                  "distance"
                ],
                "shapes": "[UUID]"
              },
              "withGeometry": "Boolean"
            },
            "search": "String",
            "q": "String"
          }
        }
      }
    ]
  },
  "format": "String (json): json",
  "language": "String: de",
  "id": "UUID",
  "include": "String",
  "page": {
    "size": "Integer: 25",
    "number": "Integer: 1",
    "offset": "Integer: 0",
    "limit": "Integer: 0"
  },
  "section": {
    "@graph": "Integer [1,0]: 1",
    "@context": "Integer [1,0]: 1",
    "meta": "Integer [1,0]: 1",
    "links": "Integer [1,0]: 1"
  },
  "sort": "String ?[+,-] (dct:modified,dct:created,name,*similarity,*proximity.geographic, proximity.geographic_with(lon,lat), *proximity.inTime, proximity.occurrence, proximity.occurrence.{sortAttribute}, random): **default",
  "token": "String"
}
```

\* = implicit sorting

\*\* = default sorting defined within project

/classification_trees = classification_tree_label_id / experimental

## Available attributes for "attributeName"

```json
{
  "attributeName": [
    "dct:created",
    "dct:modified",
    "dct:deleted",
    "schedule|eventSchedule|openingHoursSpecification|dc:diningHoursSpecification|hoursAvailable|validitySchedule"
  ]
}
```


## Available attributes for "sortAttribute"

```json
{
  "sortAttribute": [
    "eventSchedule|openingHoursSpecification|dc:diningHoursSpecification|hoursAvailable|validitySchedule"
  ]
}
```
