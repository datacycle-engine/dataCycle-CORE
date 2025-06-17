# Mapbox Vector Tiles

Mapbox Vector Tiles (MVT) haben durch ihre geringe Größe den Vorteil, dass sie in der Visualisierung optimal eingesetzt werden können. Die On-the-fly-Generierung ermöglicht eine zusätzliche Filterung mit Parametern der [allgemeinen Datenschnittstelle](/docs/api/contents), mit der die Inhalte an die spezifischen Anforderungen angepasst werden können.

<!-- Durch optimiertes Micro-Caching wird ein zusätzlicher Performance-Boost erzielt. -->

## Voraussetzungen

**Es muss eine Konfiguration hinterlegt werden, damit die Anfrage von Geodaten aktiviert ist.**

## Allgemeines

Anfragen von Daten im Format MVT werden über die MVT-Schnittstelle durchgeführt, deren Route sich unter `/mvt/v1/...` befindet.

Anfragen mit Filtern und Einschränkungen funktionieren analog zu den [Anfragen von GeoJSONs](/docs/api/geodata/geojson). Die in den MVTs codierten Attribute entsprechen ebenfalls den Attributen der gesendeten GeoJSONs.

Der Name des Daten-Layers in den Tiles lautet standardmäßig "dataCycle". Mit dem optionalen Parameter `layerName`, der bei Anfragen mitgeschickt werden kann, ist es mögliche einen eigenen Namen zu vergeben.

Zur Authentifizierung empfiehlt sich die Verwendung eines API-Token, es können aber prinzipiell alle für die Datenschnittstelle angebotenen [Authentifizierung-Mechanismen](/docs/api#authentifizierung) genutzt werden.


**Zu beachten ist, dass eine implizite Filterung auf Geo-Objekte aktiv ist. Es werden keine Daten ohne Koordinaten ausgegeben.**

## Anfragen

Es können Einzelobjekte oder Ergebnisse von Suchen bzw. Inhaltssammlungen abgefragt werden. Dafür sind die Routen `/mvt/v1/things/<THING-ID>` und `/mvt/v1/endpoints/<ENDPOINT-ID>` vorgesehen.

Anfragen können als GET oder POST-Methoden gesendet werden.

Für die Einbindung der MVT in eine Kartenanwendung muss die URL nach folgendem Schema aufgebaut sein:

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

### Clustering
#### ```cluster``` (default: false)
Gibt an, ob Ergebnisse geclustered werden sollen.

#### ```clusterLines``` (default: false)
Gibt an, ob auch Linien geclustered werden sollen (Anhand des Startpunktes).

#### ```clusterPolygons``` (default: false)
Gibt an, ob auch Polygone geclustered werden sollen (Anhand des Startpunktes).

#### ```clusterItems``` (default: false)
Gibt an, ob Informationen zu den Inhalten in einem Cluster ausgeliefert werden sollen (z.B. @id, @type)
Performance-Hinweis: Diese Option sollte nur bei der höchsten Zoomstufe verwendet werden, wenn der Cluster nicht mehr weiter aufgelöst werden kann.

#### ```clusterMaxZoom``` (default: null)
Gibt die maximale Zoomstufe an, für die geclustered werden soll.

#### ```clusterMinPoints``` (default: 2)
Gibt die minimale Anzahl an Features an, die notwendig sind, um einen Cluster zu bilden.

#### ```clusterMaxDistance``` (default: 500.000 / (1.7^Zoomstufe))
Gibt die maximale Distanz zwischen Features innerhalb eines Clusters an.
Diese Option sollte von der aktuellen Zoomstufe abhängig sein.
Einheit: Meter (Projektion: EPSG:3857)

#### Beispiel (JSON-Body)
```url
POST https://<URL>/mvt/v1/endpoints/<ENDPOINT-ID>/{z}/{x}/{y}.pbf
```
```json
{
  "cluster": true,
  "clusterLines": true,
  "clusterPolygons": true,
  "clusterItems": true,
  "clusterMaxZoom": 11,
  "clusterMinPoints": 2,
  "clusterMaxDistance": 1000
}
```
#### Beispiel (URL-Parameter)
```url
GET https://<URL>/mvt/v1/endpoints/<ENDPOINT-ID>/{z}/{x}/{y}.pbf?cluster=true&clusterLines=true&clusterPolygons=true&clusterItems=true&clusterMaxZoom=11&clusterMinPoints=2&clusterMaxDistance=1000
```
