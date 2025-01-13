# Optimierungen bei der Abfrage von Daten

Durch die Nutzung von bestimmten Parametern kann die Antwortzeit in bestimmten Fällen reduziert werden.

## Anzahl der Inhalte (```meta.total```, ```meta.pages```)

Standardmäßig wird bei jeder Seite die Anzahl der Inhalte (```meta.total```), sowie die Anzahl der Seiten (```meta.pages```) ausgegeben. Um diese Werte bereitzustellen, ist allerdings jedesmal eine eigene Datenbankabfrage notwendig.

Wenn die Anzahl der Inhalte also nicht zwingend benötigt wird, kann man den ```meta``` Block von der Anfrage ausnehmen:

```json
{
  "section": {
    "meta": 0
  }
}
```

Auch ohne die Anzahl der Inhalte / Seiten kann über die ```links``` festgestellt werden, wann man auf der letzten bzw. ersten Seite angelangt ist. Die jeweiligen Links sind nur vorhanden, wenn es eine nächste bzw. vorige Seite gibt.

## Einschränken der Attribute (```fields```)

Das Anfordern von Inhalten ohne Einschränkung über ```fields``` liefert alle verfügbaren Attribute aus.

Wenn sich ein Inhalt gerade geändert hat, gibt es dafür noch keinen aktuellen Eintrag im Cache und das Ausgeben der Attribute dauert länger, je nachdem, wie viele Attribute angefordert werden.

Daher empfiehlt es sich, die Attribute auf jene einzuschränken, die wirklich benötigt werden.

Das kann einfach mit ```fields``` erreicht werden. Pfade innerhalb von ```fields``` werden automatisch inkludiert und müssen nicht zusätzlich in ```include``` angegeben werden.

Mehr dazu unter [Abfragen von ausgewählten Attributen](/docs/api#abfragen-von-ausgew-hlten-attributen)
