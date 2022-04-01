# Classifications (concepts) specification
```javascript
{
    "apiSubversion": "String",
    "contentId": "UUID",
    "fields": "String",
    "filter": {
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
        "search": "String",
        "q": "String"
    },
    "format": "String (json): json",
    "language": "String: de",
    "id": "UUID",
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
## Available attributes for "attributeName" 
```javascript
{
    "attributeName":
        [
            "dct:created",
            "dct:modified",
            "dct:deleted"
        ]
}
```