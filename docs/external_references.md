# Verknüpfung zu externen Systemen

## Übersicht

dataCycle unterstützt die Verwaltung von Inhalten, die in mehreren externen Systemen existieren. Diese Dokumentation beschreibt das Verhalten bei Import, Export und Löschen solcher Inhalte.

## Verknüpfungstypen

dataCycle unterscheidet drei Arten von externen Verknüpfungen:

- **"Importiert von"**: Quellsysteme, aus denen Inhalte importiert wurden
- **"Duplikat"**: Zusätzliche externe Referenzen auf denselben Inhalt
- **"Exportiert nach"**: Zielsysteme, in die Inhalte exportiert wurden

## Import von Inhalten mit mehreren Referenzen

### Beispiel: Outdooractive-Import mit feratel Deskline-ID

Bestimmte Importer (z.B. Outdooractive) liefern zusätzlich zu ihren eigenen IDs auch IDs anderer Systeme (z.B. feratel Deskline).

#### Fall 1: Neuer Inhalt

Wenn der Inhalt noch nicht in dataCycle existiert:

1. **Outdooractive** wird als primäre Verknüpfung vom Typ "Importiert von" angelegt
2. **feratel Deskline** wird als zusätzliche Verknüpfung vom Typ "Duplikat" hinzugefügt

#### Fall 2: Inhalt bereits vorhanden

Wenn der Inhalt bereits von feratel Deskline importiert wurde:

1. Der bestehende Inhalt wird über die feratel Deskline-ID erkannt
2. **Outdooractive** wird als zusätzliche Verknüpfung vom Typ "Importiert von" ergänzt
3. **feratel Deskline** bleibt die **primäre Verknüpfung** (aktuellste "Importiert von"-Verknüpfung)

## Löschen von Inhalten durch den Importer

### Verhalten beim Löschen der primären Quelle

Wenn ein Inhalt aus seinem primären Import-System gelöscht wird (z.B. feratel Deskline), prüft der Importer zunächst die vorhandenen Verknüpfungen.

#### Szenario A: Alternative Import-Verknüpfungen vorhanden

**Bedingung**: Mindestens eine weitere Verknüpfung vom Typ "Importiert von" existiert

**Aktion**:
1. Die **aktuellste** der vorhandenen "Importiert von"-Verknüpfungen wird zur neuen primären Verknüpfung
2. Die Verknüpfung zum ursprünglichen System (feratel Deskline) wird gelöscht
3. **Der Inhalt bleibt erhalten**

#### Szenario B: Keine alternativen Import-Verknüpfungen

**Bedingung**: Keine weitere Verknüpfung vom Typ "Importiert von" existiert

**Aktion**:
- **Der Inhalt wird gelöscht**

## Beispiel-Workflow

```
Zeitlicher Ablauf:

1. Import von feratel Deskline
   → Inhalt A erstellt
   → Primäre Verknüpfung: feratel Deskline (Importiert von)

2. Import von Outdooractive (mit feratel Deskline-ID)
   → Inhalt A wird erkannt
   → Neue Verknüpfung: Outdooractive (Importiert von)
   → Primäre Verknüpfung bleibt: feratel Deskline

3. Löschen in feratel Deskline
   → Prüfung: Outdooractive-Verknüpfung vorhanden?
   → Outdooractive wird neue primäre Verknüpfung
   → feratel Deskline-Verknüpfung wird entfernt
   → Inhalt A bleibt erhalten
```

## Hinweise

- Die **primäre Verknüpfung** ist immer die erste Quelle, aus der ein Inhalt import wurde, außer es wurden **Prioritäten** konfiguriert
- Beim Löschen von Inhalten durch den Importer wird immer die **aktuellste** der vorhandenen "Importiert von"-Verknüpfungen zur neuen primären Verknüpfung
- Über eine Konfiguration kann die **Priorität** von externen Quellen definiert werden
- Die primäre Verknüpfung kann manuell im UI geändert werden
- Verknüpfungen vom Typ "Duplikat" werden **nicht** zur primären Verknüpfung befördert und haben somit keinen Einfluss auf das Löschen von Inhalten
