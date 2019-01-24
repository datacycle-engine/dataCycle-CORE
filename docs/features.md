# Funktionskatalog

## Datenstruktur
* Strukturierte Stammdaten auf Basis von [schema.org](https://schema.org/)
  * [Place](https://schema.org/Place) für allgemeine Örtlichkeiten (z.B. normale POIs)
  * [LodgingBusiness](https://schema.org/LodgingBusiness) für Unterkünfte
  * [SportsActivityLocation](https://schema.org/SportsActivityLocation) (z.B. für Touren)
  * [Event](https://schema.org/Event) für allgemeine Veranstaltungen
  * [Person](https://schema.org/Person) für Personen, die im Rahmen von anderen Datensätzen verwendet werden
  * [Organization](https://schema.org/Organization) für Organisationen, die im Rahmen von anderen Datensätzen verwendet werden
  * Beliebige weitere bzw. spezifischere Datendefinitionen von [schema.org](https://schema.org/) können jederzeit ergänzt werden
  * Ergänzen der Inhaltstypen um beliebige, benutzerdefinierte Klassifizierungen

* Strukturierte Kreativdaten auf Basis von [schema.org](https://schema.org/)
  * [ImageObject](https://schema.org/ImageObject) für Fotos bzw. Bilder mit Verknüpfungen zu Fotografen und Rechteinhabern
  * [VideoObject](https://schema.org/VideoObject) für Videos mit Verknüpfungen Regiseur, Kameramann, ...
  * [AudioObject](https://schema.org/AudioObject) für Audio-Dateien mit Verknüpfungen zu Erstellern, Sprechern, ...
  * [Article](https://schema.org/Article) für allgemeine Artikel
  * [Recipe](https://schema.org/Recipe) für Kochrezepte
  * Beliebige weitere Datendefinitionen von [schema.org](https://schema.org/) können jederzeit ergänzt werden
  * Ergänzen der Inhaltstypen um beliebige, benutzerdefinierte Klassifizierungen

* Erstellen von benutzerdefinierten Inhaltstypen
  * Verwenden von unterschiedlichen Attributtypen (z.B. formatierter Text, unformtierter Text, Datum, Geo-Koordinaten, ...)
  * Einbetten von verschachtelten Inhalten
  * Verknüpfen von unterschiedlichen Inhalten
     * Einschränkungen bei der der Verknüpfung von Inhalten auf Basis von Inhaltstypen
     * Einschränkungen bei bei der Verknüpfung von Inhalten auf Basis von beliebigen Klassifizierungen
  * Einbetten von Dateien (z.B. Textdateien, PDFs, ...)
     * Einschränkungen beim Upload von Dateien auf Basis von unterschiedlichen Meta-Attribute (z.B. Größe von Bildern, Codec bei Videos)

* **Erstellen eines Knowledge Graphen**
  * **Erstellen von partiellen Knowledge Graphen**

* Erfassen von Inhalten in beliebig vielen unterschiedlichen Sprachen


## Klassifizierungen

* Klassifzierung von Inhalten über beliebig viele unabhängige Klassifizierungsbäume
  * Klassifizierung von Inhalte auf Basis von unterschiedlichen Kritierien (z.B.: Dateiformat, Farbraum, Zielgruppe)

* Konsolidieren von verschiedenen Klassifizierungsbäumen über ein Klassifizierungsmapping
  * Aufspalten von generischen Klassifizierungsbäumen (z.B. Tags) in speziellere Klassifizierungsbäume (z.B. Zielgruppen, Urlaubsregionen)
  * Zusammenführen von fein granulierten Klassifizierungsbäumen (z.B. für einfache Filtermöglichkeiten auf einer Website)

* Übersicht über erfasste Inhalte in Form einer hierarchischen Darstellung von Klassifizierungsbäumen


## Anbindung von / Integration mit externen Systemen

* **Prinzipell können alle Arten von externen Systemen an dataCycle angebunden werden**
* Importieren von Inhalten aus externen Datenquellen (über einen Pull-Mechanismus)
  * Konfigurieren eines regelmäßigen Datenabgleichs pro externer Datenquelle
  * Überführen von externen Datenstrukturen auf interne Datenstrukturen (bevorzugt [schema.org](https://schema.org/))
  * Überführen von gleichen Inhaltstypen (z.B. POI) von unterschiedlichen Systemen auf die gleiche Zieldatenstruktur
  * Verarbeiten von Änderungen von externen Systemen über eingehende Webhooks (eingehender Push-Mechanismus)
  * Fertige Importer für populäre Datenverarbeitungssysteme
     * Feratel Deskline
     * OutdoorActive
     * Google Places
     * Google My Business
     * Bergfex
     * Booking.com

* Verständigen von externen Systemen bei Änderungen über Webhooks (ausgehender Push-Mechanismus)
  * Einschränken der kommunizierten Änderungen auf Datensatzebene auf Basis von Inhaltstypen, Klassifizierungen, ...


## Suchen / Filtern von Inhalten

* Volltextsuche
* Filtern von Inhalten auf Basis von Klassifizierungen
* Filtern von Inhalten auf Basis von Sprachen
* Filtern von Inhalten auf Basis des Erstellers
* Kombinieren von beliebig vielen verschiedenen Filtern (Multidimensionale Filterung von Inhalten)
* Einfacher Zugriff auf zuletzt abgesetzte Suchen bzw. Inhaltsfilter
* Speichern von Suchen bzw. Inhaltsfiltern für einfachen, späteren Zugriff
* Freigeben von Suchen bzw. Inhaltsfiltern für andere Benutzer


## Berechtigungen

* Einschränkungen beim Erstellen von neuen Inhalten für bestimme Benutzer auf Basis von Rollen und Gruppen
* Einschränkungen beim Bearbeiten von Inhalten für bestimme Benutzer auf Basis von Rollen und Gruppen
* Ausblenden von einzelnen Inhaltsattributen auf Basis von Rollen und Gruppen
* Fein granulierte Rechtevergabe auf Basis von Inhaltsklassifizierungen
* Einschränken der Bearbeitungsmöglichkeiten von Inhalten für einzelne Attribute auf Benutzerbasis


## Redaktionssystem

* Organisieren von Inhalten in Inhaltscontainern
  * Filtern / Suchen von Inhalten innerhalb von Inhaltscontainern
  * Erstellen von eingeschränkten Inhaltstypen innerhalb von Inhaltscontainern
* Erstellen von Inhaltssammlungen
  * Hinzufügen von beliebigen, unterschiedliche Inhalten zu einer einzigen Sammlung
  * Erstellen von beliebig vielen Inhaltssammlungen pro Benutzer
  * Teilen von Inhaltssammlungen mit anderen Benutzern über Benutzergruppen
  * Freigeben von Inhaltssammlungen für externe Benutzer
  * Zeitliche Einschränkung beim Freigeben von Inhalten für externe Benutzer
  * Möglichkeit zum Einschränken der Zugriffsrechte für externe Benutzer (Lesen/Schreiben)
* Freigeben von einzelnen Inhalten für externe Benutzer
  * Zeitliche Einschränkung beim Freigeben von Inhalten für externe Benutzer
  * Hinzufügen von AGBs für externe Benutzer
* Abonnieren von Inhalten
  * Konfigurieren der zeitlichen Intervalle bei Verständigungen über geänderte Inhalte auf Benutzerebene
* Nachverfolgen von Inhaltsänderungen
  * Hervorheben von Änderungen für verknüpfte Inhalte, eingebettete Inhalte, Klassifizierungen und einzelne Textpassagen
  * Vergleichen von unterschiedlichen Inhalten
* Einrichten von Bearbeitungsworkflows für einzelne Inhalte bzw. Inhaltscontainer
* Erstellen/Bearbeiten von Inhalten auf Basis eines anderen Inhalts als Vorlage


## Sonstiges

* Ausdrucken von Inhalten
