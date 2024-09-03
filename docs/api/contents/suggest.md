# Datenschnittstelle für Autovervollständigung

In dataCycle gibt es die Möglichkeit, Vorschläge zur Autovervollständigung für Inhalte abzurufen.

### Autovervollständigung des Titels:

```url
_/api/v4/endpoints/<ENDPOINT-ID>/suggest_by_title?token=<YOUR_ACCESS_TOKEN>&search=<SEARCH_TERM>
```
#### HTTP-POST:

```url
_/api/v4/endpoints/<ENDPOINT-ID>/suggest_by_title
```
JSON-Body:
```json
{
  "token": "YOUR_ACCESS_TOKEN",
  "search": "SEARCH_TERM"
}
```

#### Rückgabewert

Der Rückgabewert hat folgendes Schema:

```json
{
  "@context": [...]
  "@graph": {
    "@type": "dcls:Statistics",
    "suggest": [
      "test",
      "Test",
      "TEST",
      "Test 1",
      "Test 2",
      "Test 3",
      "test3",
    ]
  }
}
```
