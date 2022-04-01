<!-- # Funktionskatalog

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
  * [ImageObject](https://schema.org/ImageObject) für Fotos bzw. Bilder mit Verknüpfungen zu Fotograf und Rechteinhaber
  * [VideoObject](https://schema.org/VideoObject) für Videos mit Verknüpfungen zu Regisseur, Kameramann, ...
  * [AudioObject](https://schema.org/AudioObject) für Audio-Dateien mit Verknüpfungen zu Ersteller, Sprecher, ...
  * [Article](https://schema.org/Article) für allgemeine Artikel
  * [SocialMediaPosting](https://schema.org/SocialMediaPosting) für Postings in verschiedenen Social-Media-Kanälen
  * [Recipe](https://schema.org/Recipe) für Kochrezepte
  * Beliebige weitere Datendefinitionen von [schema.org](https://schema.org/) können jederzeit ergänzt werden
  * Ergänzen der Inhaltstypen um beliebige, benutzerdefinierte Klassifizierungen

* Erstellen von benutzerdefinierten Inhaltstypen
  * Verwenden von unterschiedlichen Attributtypen (z.B. formatierter Text, unformatierter Text, Datum, Geo-Koordinaten, ...)
  * Einbetten von verschachtelten Inhalten
  * Verknüpfungen von beliebigen, unterschiedlichen Inhalten
     * Einschränkungen bei der Verknüpfung auf Basis von Inhaltstypen
     * Einschränkungen bei der Verknüpfung auf Basis von beliebigen Klassifizierungen
  * Einbetten von Dateien (z.B. Textdateien, PDFs, ...)
     * Einschränkungen beim Upload von Dateien auf Basis von unterschiedlichen Meta-Attribute (z.B. Größe bei Bildern, Codec bei Videos)

* Speichern der Inhalte innerhalb eines Knowledge Graphen
  * Erstellen von partiellen Knowledge Graphen (für externen Zugriff über die Datenschnittstelle)
  * Mögliche Navigation anhand von Links (Verknüpfungen) im Knowledge Graph
  * Möglicher Datenzugriff direkt über eine Graph-Datenbank

* Erfassen von Inhalten in beliebig vielen, unterschiedlichen Sprachen


## Klassifizierungen

* Klassifizierung von Inhalten über beliebig viele unabhängige Klassifizierungsbäume
  * Klassifizierung von Inhalte auf Basis von unterschiedlichen Kriterien (z.B.: Dateiformat, Farbraum, Zielgruppe)

* Konsolidieren von verschiedenen Klassifizierungsbäumen über ein Klassifizierungsmapping
  * Aufspalten von generischen Klassifizierungsbäumen (z.B. Tags) in speziellere Klassifizierungsbäume (z.B. Zielgruppen, Urlaubsregionen)
  * Zusammenführen von fein granulierten Klassifizierungsbäumen (z.B. für einfache Filtermöglichkeiten auf einer Website)

* Übersicht über erfasste Inhalte in Form einer hierarchischen Darstellung innerhalb von Klassifizierungsbäumen


## Anbindung von / Integration mit externen Systemen

* Prinzipiell können alle Arten von externen Systemen an dataCycle angebunden werden
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
     * ...

* Verständigen von externen Systemen bei Änderungen über Webhooks (ausgehender Push-Mechanismus)
  * Einschränken der kommunizierten Änderungen auf Datensatzebene auf Basis von Inhaltstypen, Klassifizierungen, ...
  * Weitergabe der Daten in unterschiedlichen Zielformaten

* Möglichkeit zum Verknüpfen von mehreren, unabhängigen dataCycle-Instanzen

* Integration mit bereits bestehender Cloud

* Verknüpfen von Inhalten aus unterschiedlichen Quellsystemen miteinander oder mit dataCycle-internen Inhalten


## Suchen / Filtern von Inhalten

* Volltextsuche
* Filtern von Inhalten auf Basis von Klassifizierungen
* Filtern von Inhalten auf Basis von Sprachen
* Filtern von Inhalten auf Basis des Erstellers
* Filtern von Inhalten auf Basis des Quellsystems
* Kombinieren von beliebig vielen verschiedenen Filtern (Multidimensionale Filterung von Inhalten)
* Einfacher Zugriff auf zuletzt abgesetzte Suchen bzw. Inhaltsfilter
* Speichern von Suchen bzw. Inhaltsfiltern für einfachen, späteren Zugriff
* Freigeben von Suchen bzw. Inhaltsfiltern für andere Benutzer


## API

* Datenschnittstelle auf Basis von offenen Standards
  * [JSON-LD](https://json-ld.org/)
  * [JSON API](http://jsonapi.org)
  * [schema.org](https://schema.org/)
  * Einfacher Zugriff auf in dataCycle gespeicherten Daten für externe Systeme (Websites, Karten, Newsletter, PDF-Generatoren, ...)

* Erstellen von beliebig vielen, externen Datenschnittstellen über gespeicherte Inhaltsfilter
  * Einfache Nachvollziehbarkeit der ausgelieferten Daten
  * Filtern der vorgefilterten Daten auf Basis von Klassifizierungen
  * Volltextsuche über die vorgefilterten Inhalte
  * Einschränken des Zugriffs für ausgewählte Benutzer

* Freigeben von Inhaltssammlungen
  * Händisches Zusammenstellen von explizit ausgewählten Inhalten
  * Weitergabe der Inhalte über JSON-Schnittstelle

* Versionierung von Inhaltsdefinitionen
  * Erweitern von Inhaltstypen für neue Anwendungen
  * Ändern von Serialisierungsdetails (z.B. aufgrund von Änderungen im Datenstandard)
  * Weiterverwenden von alten API-Endpunkten für legacy-Anwendungen

* Zugriff auf Inhalte über GraphQL
  * Einschränken von ausgelieferten Inhaltsfeldern für optimale Performance beim Datenzugriff


## Benutzerverwaltung

* Unterschiedliche Typen von Benutzern
  * Personen
  * Organisationen (z.B. für technische Benutzer)
* Externe Benutzer
  * Authentifizierung über vorhandenes systemübergreifendes Authentifizierungssystem (z.B. via SSO) möglich
* Kategorisieren von Benutzern auf zwei Ebenen
  * Rollen
  * Gruppen


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
  * Hinzufügen von beliebigen, unterschiedlichen Inhalten zu einer generischen Inhaltssammlung
  * Erstellen von beliebig vielen Inhaltssammlungen pro Benutzer
  * Teilen von Inhaltssammlungen mit anderen Benutzern über Benutzergruppen
  * Freigeben von Inhaltssammlungen für externe Benutzer
  * Zeitliche Einschränkung beim Freigeben von Inhalten für externe Benutzer
  * Möglichkeit zum Einschränken der Zugriffsrechte für externe Benutzer (Lesen/Schreiben)
* Freigeben von einzelnen Inhalten für externe Benutzer
  * Zeitliche Einschränkung beim Freigeben von Inhalten für externe Benutzer
  * Möglichkeit zum Einschränken der Zugriffsrechte für externe Benutzer (Lesen/Schreiben)
  * Hinzufügen von AGBs für externe Benutzer
* Abonnieren von Inhalten
  * Konfigurieren der zeitlichen Intervalle bei Verständigungen über geänderte Inhalte auf Benutzerebene
* Nachverfolgen von Inhaltsänderungen
  * Hervorheben von Änderungen für verknüpfte Inhalte, eingebettete Inhalte, Klassifizierungen und einzelne Textpassagen
  * Vergleichen von unterschiedlichen Inhalten
* Planen von Veröffentlichungszeitpunkte über einen speziellen Publikationskalender
  * Chronologische Übersicht über alle geplanten Veröffentlichungen
  * Filtermöglichkeiten innerhalb des Publikationskalenders auf Basis von Klassifizierungen und Sprachen
* Einrichten von Bearbeitungsworkflows für einzelne Inhalte bzw. Inhaltscontainer
* Verwenden von Inhaltspools zum Abbilden des Lebenszyklus von Inhalten (z.B. "Aktuelle Inhalte" und "Archiv")
* Erstellen/Bearbeiten von Inhalten auf Basis eines anderen Inhalts als Vorlage


## Medienverwaltung

* Zentraler Upload von neuen Mediendateien
  * Möglichkeit zum Mehrfachupload
  * Vorschaufunktion bei unterstützten Dateiformaten
  * Einschränken des Uploads von neuen Mediendateien auf Basis von verschiedenen Meta-Attributen
     * Dateityp (z.B. JPG, JPEG, PNG, GIF bei Bilddateien)
     * Kodierungsverfahren (z.B. H.264 bei Videos)
     * Größe von Bildern (z.B. mindestens 1280x720 Pixel)
     * Dateigröße

* Konvertieren von hochgeladenen Mediendateien in fest definierte Formate (z.B. für Thumbnails)

* Extrahieren von Meta-Daten (z.B. EXIF bei Fotos; ID3 bei Audio)

* Automatisches Erkennen von Dubletten bei Bildern auf Basis des Bildmotivs


## Sonstiges

* Ausdrucken von Inhalten
* Geo-Coding von Inhalten auf Basis von Adressen
* Reverse Geo-Coding auf Basis von Geo-Koordinaten
* Normalisieren von Adressdaten
* Installation auf beliebiger Server-Infrastruktur (mit dem Betriebssystem Linux) im hausinternen Data-Center -->
