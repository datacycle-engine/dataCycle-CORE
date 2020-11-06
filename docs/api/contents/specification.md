# Content specification
```javascript
{
    "apiSubversion": "String",
    "fields": "String",
    "filter": {
        "contentId": {
            "in": "[UUID]",
            "notIn": "[UUID]"
        },
        "filter_id": {
            "in": "[UUID]",
            "notIn": "[UUID]"
        },
        "watchListId": {
            "in": "[UUID]",
            "notIn": "[UUID]"
        },
        "attribute": {
            "{attributeName}":{
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
                "box": ["swLon","swLat","neLon","neLat"],
                "perimeter": ["lon","lat","distance"],
                "shapes": "[UUID]",
            },
            "notIn": {
                "box": ["swLon","swLat","neLon","neLat"],
                "perimeter": ["lon","lat","distance"],
                "shapes": "[UUID]",
            }
        },
        "search": "String",
        "q": "String",
        "linked": {
            "contentId": {
                "in": "[UUID]",
                "notIn": "[UUID]"
            },
            "filter_id": {
                "in": "[UUID]",
                "notIn": "[UUID]"
            },
            "watchListId": {
                "in": "[UUID]",
                "notIn": "[UUID]"
            },
            "{attributeName(,attributeName)}": {
                "attribute": {
                    "{attributeName}":{
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
                        "box": ["swLon","swLat","neLon","neLat"],
                        "perimeter": ["lon","lat","distance"],
                        "shapes": "[UUID]",
                    },
                    "notIn": {
                        "box": ["swLon","swLat","neLon","neLat"],
                        "perimeter": ["lon","lat","distance"],
                        "shapes": "[UUID]",
                    }
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
                "filterId": {
                    "in": "[UUID]",
                    "notIn": "[UUID]"
                },
                "watchListId": {
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
                    "box": ["swLon", "swLat", "neLon", "neLat"],
                    "perimeter": ["lon", "lat", "distance"],
                    "shapes": "[UUID]"
                    },
                    "notIn": {
                    "box": ["swLon", "swLat", "neLon", "neLat"],
                    "perimeter": ["lon", "lat", "distance"],
                    "shapes": "[UUID]"
                    }
                },
                "search": "String",
                "q": "String",
                "linked": {
                    "contentId": {
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
                    "{attributeName(,attributeName)}": {
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
                        "box": ["swLon", "swLat", "neLon", "neLat"],
                        "perimeter": ["lon", "lat", "distance"],
                        "shapes": "[UUID]"
                        },
                        "notIn": {
                        "box": ["swLon", "swLat", "neLon", "neLat"],
                        "perimeter": ["lon", "lat", "distance"],
                        "shapes": "[UUID]"
                        }
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
    "sort": "String ?[+,-] (dct:modified,dct:created,name,*similarity,*proximity.geographic, *proximity.in_time, random): **default",
    "token": "String"
} 
```
\* = implicit sorting

\** = default sorting defined within project

## Available attributes for "attributeName" 
```javascript
{
    "attributeName":
        [
            "dct:created",
            "dct:modified",
            "dct:deleted",
            "schedule"
        ]
}
```