# Mapbox Vector Tiles

Mapbox Vector Tiles (MVT) haben durch ihre geringe Größe den Vorteil, dass sie in der Visualisierung optimal eingesetzt werden können. Die On-the-fly-Generierung ermöglicht eine zusätzliche Filterung mit Parametern der [allgemeinen Datenschnittstelle](/docs/api/contents), mit der die Inhalte an die spezifischen Anforderungen angepasst werden können.

<!-- Durch optimiertes Micro-Caching wird ein zusätzlicher Performance-Boost erzielt. -->

## Voraussetzungen

**Es muss eine Konfiguration hinterlegt werden, damit die Anfrage von Geodaten aktiviert ist.**

## Allgemeines

Anfragen von Daten im Format MVT werden über die MVT-Schnittstelle durchgeführt, deren Route sich unter `/mvt/v1/...` befindet.

Anfragen mit Filtern und Einschränkungen funktionieren analog zu den [Anfragen von GeoJSONs](/docs/api/geodata/geojson). Die in den MVTs codierten Attribute entsprechen ebenfalls den Attributen der gesendeten GeoJSONs.

Zur Authentifizierung muss das API-Token, als URL-Parameter, im JSON-Body oder als Bearer-Token im HTTP-Header mitgesendet werden.

**Zu beachten ist, dass eine implizite Filterung auf Geo-Objekte aktiv ist. Es werden keine Daten ohne Koordinaten ausgegeben.**

## Anfragen

Es können Einzelobjekte oder Ergebnisse von Suchen bzw. Inhaltssammlungen abgefragt werden. Dafür sind die Routen `/mvt/v1/things/<THING-ID>` und `/mvt/v1/endpoints/<ENDPOINT-ID>` vorgesehen.

Anfragen können als GET oder POST-Methoden gesendet werden.

Für die Einbindung der MVT in eine Kartenanwendung muss dir URL nach folgendem Schema aufgebaut sein:

```url
https://<URL>/mvt/v1/endpoints/<ENDPOINT-ID>/{z}/{x}/{y}.pbf
```

### Bounding Box der aktuellen Daten

Für eine Anfrage über `/mvt/v1/endpoints/<ENDPOINT-ID>` kann die Bounding Box (BBox) für die Summe der zurückgegebenen Objekte abgefragt werden. Dafür muss der Parameter `bbox` im JSON-Body mitgegeben werden.

```bash
curl --request POST \
  --url https://<URL>/mvt/v1/endpoints/<ENDPOINT-ID> \
  --header 'Authorization: Bearer <TOKEN>' \
  --header 'Content-Type: application/json' \
  --data '{
 "bbox": true
    }'
```
