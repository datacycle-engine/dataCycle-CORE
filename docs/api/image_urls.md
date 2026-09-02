# Individuelle Bild-URLs (imgproxy)

Ist für eine dataCycle-Instanz ein Bild-Proxy ([imgproxy](https://imgproxy.net)) vorgeschaltet, werden Bilder nicht direkt ausgeliefert, sondern erst bei der Anfrage in der gewünschten Größe und im gewünschten Format erzeugt und anschließend zwischengespeichert. Die dafür nötigen URLs sind signiert und werden über die Datenschnittstelle in einigen vorkonfigurierten Varianten ausgeliefert (z.B. `contentUrl`, `thumbnailUrl`, `dc:webUrl`).

Wird eine Größe oder ein Zuschnitt benötigt, der nicht als Variante vorkonfiguriert ist, kann über den Endpunkt `/assets/imgproxy_url/<THING-ID>` eine signierte URL für beliebige Parameter erzeugt werden.

**Der Endpunkt liefert kein Bild aus, sondern ausschließlich die URL, über die das Bild anschließend abgerufen werden kann.**

## Voraussetzungen

**Der Bild-Proxy muss für die jeweilige dataCycle-Instanz konfiguriert und aktiviert sein.** Ist das nicht der Fall, antwortet der Endpunkt mit `401 Unauthorized` (siehe [Fehler](#fehler)).

Zusätzlich muss der angefragte Inhalt vom Bild-Proxy verarbeitet werden können. Unterstützt werden die Inhaltstypen `Bild` (`ImageObject`, `ImageVariant`, `ImageObjectVariant`), `Video` (`VideoObject`) und `PDF`, sofern eine Datei hochgeladen oder eine externe Datei (`contentUrl`) hinterlegt ist.

## Allgemeines

Die Anfrage erfolgt ausschließlich über **HTTP-POST** an `/assets/imgproxy_url/<THING-ID>`, wobei `<THING-ID>` die UUID des Inhalts ist. Die Antwort ist immer **JSON**.

Zur Authentifizierung können alle für die Datenschnittstelle angebotenen [Authentifizierungs-Mechanismen](/docs/api#authentifizierung) genutzt werden. Das Token kann dabei als HTTP-Header, als Query-Parameter oder als Attribut `token` im JSON-Body übergeben werden.

Die Bildparameter werden im JSON-Body unter `transformation` übergeben. **`width`, `height` und `enlarge` müssen echte JSON-Zahlen sein**, in Anführungszeichen gesetzte Werte werden mit `400 Bad Request` abgelehnt. Eine formularkodierte Anfrage (`application/x-www-form-urlencoded`) ist aus dem gleichen Grund nicht möglich.

Für Anfragen aus dem eingeloggten Frontend ist kein CSRF-Token notwendig.

## Parameter

Alle Parameter werden innerhalb von `transformation` erwartet.

##### `width` / `height` (required: true)

Maximale Breite bzw. Höhe des Ergebnisses in Pixel. Wird nur einer der beiden Werte angegeben, wird der andere automatisch auf den gleichen Wert gesetzt. `0` bedeutet keine Begrenzung in dieser Dimension. Fehlen beide Werte, wird die Anfrage mit `400 Bad Request` abgelehnt.

##### `resize_type` (default: 'fit')

Art der Skalierung:

* `fit` – das Bild wird unter Beibehaltung des Seitenverhältnisses in die angegebene Größe eingepasst
* `fill` – das Bild wird auf die angegebene Größe zugeschnitten (der Ausschnitt wird über `gravity` gesteuert)
* `auto` – `fill` oder `fit`, abhängig von der Orientierung des Quellbildes

Andere Werte werden zwar in die URL übernommen, beim Abruf des Bildes aber mit `404 Not Found` beantwortet.

##### `gravity` (default: 'sm')

Legt fest, welcher Bildausschnitt bei `resize_type: fill` erhalten bleibt. Neben `sm` (Smart Crop, automatische Erkennung des relevanten Bildbereichs) sind die Himmelsrichtungen `ce`, `no`, `so`, `ea`, `we`, `noea`, `nowe`, `soea`, `sowe` sowie ein relativer Fokuspunkt in der Form `fp:<x>:<y>` (Werte zwischen `0` und `1`) möglich.

##### `enlarge` (default: 0)

Mit `1` werden Bilder, die kleiner als die angeforderte Größe sind, hochskaliert, mit `0` bleiben sie in ihrer ursprünglichen Größe.

##### `extension` (default: nicht gesetzt)

Zielformat des Bildes. Zulässig sind `jpg`, `jpeg`, `png`, `webp`, `avif` und `gif`; andere Werte erzeugen eine URL, deren Signatur nicht zum Bild passt und die beim Abruf mit `403 Forbidden` beantwortet wird.

Ohne Angabe enthält die URL keine Dateiendung und das Format wird anhand des `Accept`-Headers der Bild-Anfrage gewählt (`webp` bzw. `avif` für Browser, die diese Formate unterstützen). Das ist in der Regel die bessere Variante, da so pro Client das jeweils kleinste Format ausgeliefert wird.

## Anfrage

```bash
curl --request POST \
  --url https://<URL>/assets/imgproxy_url/<THING-ID> \
  --header 'Authorization: Bearer <TOKEN>' \
  --header 'Accept: application/json' \
  --header 'Content-Type: application/json' \
  --data '{
    "transformation": {
      "resize_type": "fill",
      "width": 800,
      "height": 600,
      "enlarge": 0,
      "gravity": "sm",
      "extension": "jpg"
    }
  }'
```

## Rückgabewert

```json
{
  "url": "https://<URL>/asset/<THING-ID>/<SIGNATUR>/<CACHEBUSTER>/default/fill/800/600/0/sm/<DATEINAME>.jpg"
}
```

Die URL enthält neben den angeforderten Parametern die Signatur sowie einen Cachebuster, der sich aus dem letzten Änderungszeitpunkt des Inhalts ergibt. Dadurch liefert der Endpunkt eine neue URL, sobald das Bild ersetzt oder bearbeitet wird; bis dahin kann die URL dauerhaft zwischengespeichert werden (siehe [Aktualisierung des Bildes](#aktualisierung-des-bildes)).

**Die Signatur gilt nur für genau diese Parameter-Kombination.** Wird die URL nachträglich verändert (z.B. eine andere Breite eingesetzt), wird sie vom Bild-Proxy abgewiesen. Für eine andere Größe muss eine neue URL angefragt werden.

Kann der Inhalt nicht über den Bild-Proxy verarbeitet werden (z.B. weil es sich um einen nicht unterstützten Inhaltstyp handelt oder keine Datei hinterlegt ist), wird mit `200 OK` und `"url": null` geantwortet.

## Aktualisierung des Bildes

Der Cachebuster in der URL entspricht dem letzten Änderungszeitpunkt des Bild-Inhalts. Über die Datenschnittstelle wird dieser Zeitpunkt als APIv4-Attribut **`dc:touched`** ausgeliefert. Wie `dct:created` und `dct:modified` muss er explizit beim Parameter `fields` angefragt werden (siehe [Abfragen von Inhalten über die Datenschnittstelle](/docs/api/contents)):

```json
{
  "token": "YOUR_ACCESS_TOKEN",
  "fields": "contentUrl,dc:touched"
}
```

**Maßgeblich ist immer das `dc:touched` des Bildes selbst**, nicht das des Inhalts, über den das Bild verknüpft ist (z.B. eines Artikels). Bei verknüpften Bildern muss das Attribut daher auf der jeweiligen Verknüpfung angefragt werden, z.B. `"fields": "name,image.dc:touched"`.

Wird das Bild ersetzt oder bearbeitet, ändert sich `dc:touched` und damit sowohl der Cachebuster als auch die Signatur der URL. Eine zuvor bezogene URL wird dadurch aber nicht ungültig: Sie bleibt korrekt signiert, verweist aber auf einen veralteten Stand. Da der Bild-Proxy das Quellbild immer in der aktuellen Version bezieht, ist nicht vorhersehbar, welches Bild über eine veraltete URL ausgeliefert wird — solange die alte Variante zwischengespeichert ist, das alte Bild, danach das neue Bild mit den alten Transformationsparametern.

**Eine über diesen Endpunkt bezogene URL muss daher gemeinsam mit dem `dc:touched` des Bildes gespeichert werden. Ändert sich `dc:touched`, muss die URL neu angefragt werden**, damit sichergestellt ist, dass das korrekte Ausgangsbild verwendet wird. Das gilt für alle abgeleiteten URLs eines Bildes: Sind zu einem Bild mehrere Varianten in Verwendung, müssen alle davon neu angefragt werden.

`dc:touched` ändert sich auch bei Änderungen, die die Bilddatei selbst nicht betreffen (z.B. bei geänderten Metadaten oder Klassifizierungen sowie bei einer serverseitigen Invalidierung des Caches). Eine dann neu angefragte URL ist zwar nicht zwingend notwendig, aber unproblematisch — sie liefert dasselbe Bild aus und wird lediglich neu erzeugt und zwischengespeichert.

## Fehler

Ohne gültige Authentifizierung wird mit `401 Unauthorized` geantwortet:

```json
{
  "errors": [
    {
      "source": {
        "pointer": "/assets/imgproxy_url/<THING-ID>"
      },
      "detail": "invalid or missing authentication token"
    }
  ]
}
```

Alle übrigen Fehler werden nach folgendem Schema ausgeliefert:

```json
{
  "error": "Missing required parameters"
}
```

* `401 Unauthorized` mit `Feature ist nicht aktiviert`, wenn der Bild-Proxy für die Instanz nicht aktiviert ist
* `400 Bad Request` mit `Missing required parameters`, wenn `transformation` fehlt oder weder `width` noch `height` angegeben ist
* `400 Bad Request` mit `Width, height and enlarge must be numbers`, wenn diese Werte nicht als JSON-Zahlen übergeben werden
* `422 Unprocessable Content`, wenn der Inhalt zur angegebenen `<THING-ID>` nicht existiert
* `404 Not Found`, wenn die angegebene `<THING-ID>` keine gültige UUID ist
