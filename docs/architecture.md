# Systemarchitektur

## 1. Grundlegende Philosophie: Der API-First-Ansatz

Das Hauptziel von `dataCycle` ist es, Daten aus heterogenen Quellsystemen zentral zusammenzuführen (Data-Hub-Ansatz) und über eine leistungsfähige, einfach nutzbare und auf etablierten, öffentlichen Standards basierende API bereitzustellen. Die Plattform ist so konzipiert, dass Daten sowohl durch den Import aus externen Systemen als auch durch die direkte Erstellung und Pflege (Data-Management-System, DMS) in `dataCycle` verwaltet werden können.

Ein zentrales Architekturprinzip ist die konsequente Harmonisierung der Daten direkt beim Import in die Core-Datenbank. Alle Daten liegen dort bereits in einer einheitlichen, sauberen Zielstruktur (Golden Record) vor. Dies vermeidet ein komplexes und fehleranfälliges Mapping bei der Datenausgabe und garantiert eine hohe Konsistenz und Performance an der Schnittstelle. Änderungen in den angebundenen Quellsystemen werden dabei automatisch in `dataCycle` übernommen, was eine mehrfache Datenpflege überflüssig macht.

Die primäre Schnittstelle zu diesem harmonisierten Datenbestand ist die `dataCycle` API. Sie basiert auf dem offenen Standard JSON-LD und ist von den flexiblen Abfragemöglichkeiten von GraphQL inspiriert, ohne dessen Komplexität zu erfordern. Wesentliche Merkmale sind:
* Die Möglichkeit, verknüpfte Inhalte über mehrere Ebenen mit abzufragen (Graph-Traversal).
* Die Möglichkeit, die ausgelieferten Attribute gezielt einzuschränken (Field-Selection).
* Ein modularer Filter-Baukasten, der die flexible Kombination verschiedener Filter ermöglicht (z.B. nach Klassifizierung, Geodaten, Terminen oder verknüpften Inhalten).

## 2. Technologischer Stack & Hosting-Architektur

Die technische Basis für `dataCycle` bildet das Web-Application-Framework „Ruby on Rails“. Die gesamte Architektur ist in **Docker-Container** gekapselt, was maximale Flexibilität beim Hosting und eine einfache Skalierbarkeit bis hin zum Betrieb in einem Kubernetes-Cluster ermöglicht.

Das Datenbank-Setup ist zweigeteilt, um den Anforderungen des Importprozesses gerecht zu werden:
* **MongoDB als Staging-Datenbank:** Hier werden die Rohdaten der Quellsysteme 1:1 und weitestgehend unverändert abgelegt. Dieser Bereich dient als sogenannte Staging Area.
* **PostgreSQL mit PostGIS als Core-Datenbank:** Diese performante, relationale Open-Source-Datenbank bildet das Herz des Systems. Sie speichert die fertig transformierten und harmonisierten Zieldaten und nutzt die **PostGIS-Erweiterung** für die hochperformante Verarbeitung von Geodaten.

## 3. Logisches Fundament: Der Knowledge Graph

`dataCycle` speichert Daten nicht in isolierten Tabellen, sondern modelliert sie als **Knowledge Graph** (auch semantisches Netz genannt). Das bedeutet, dass Inhalte als vernetzte Entitäten (Knoten) behandelt werden und die Beziehungen zwischen ihnen (Kanten) eine ebenso hohe Bedeutung haben wie die Inhalte selbst ("First-Class-Citizens").

Dieses Konzept, das dem einer **Graphdatenbank** zugrunde liegt, ist die logische Grundlage für die Datenharmonisierung und erlaubt es, komplexe Zusammenhänge der realen Welt (z.B. eine Veranstaltung findet an einem Ort statt, der von einer Organisation betrieben wird) präzise abzubilden und abzufragen.

## 4. Logisches Fundament: Das multidimensionale Klassifizierungssystem

Aufbauend auf dem Knowledge Graphen ist das Klassifizierungssystem ein weiterer zentraler Architekturbaustein. Anstatt Inhalte nur mit einfachen Tags (Schlagwörtern) zu versehen, ermöglicht `dataCycle` die Erstellung beliebig vieler, voneinander unabhängiger **Klassifizierungsbäume** (auch **Taxonomien** genannt).

Jeder dieser Bäume stellt eine eigene Ordnungsdimension dar (z.B. nach Zielgruppe, nach Region, nach Thema). Ein Inhalt kann somit multidimensional klassifiziert (kategorisiert, verschlagwortet) werden. Der entscheidende architektonische Vorteil liegt im **Klassifizierungsmapping**: Das System bietet einen Mechanismus, um Klassifizierungen aus unterschiedlichen Quellsystemen (unterschiedliche Vokabulare) auf einen zentralen, vereinheitlichten Klassifizierungsbaum abzubilden. Dies ist ein Kernprozess der Datenharmonisierung und stellt sicher, dass die Daten nicht nur strukturell, sondern auch inhaltlich konsolidiert werden.

## 5. Der zentrale Datenfluss: Der zweistuﬁge Import-Prozess (ETL-Ansatz)

Der Import von Daten in die `dataCycle` Core-Datenbank ist ein klar definierter, zweistufiger Prozess, der einem klassischen **ETL-Ansatz** (Extract, Transform, Load) folgt:

### Schritt 1: Extract (Staging)
Die Daten werden als Rohdaten aus den Quellsystemen extrahiert und in die MongoDB-Staging-Datenbank geladen. Für jeden Endpunkt einer Datenquelle wird eine eigene "Collection" angelegt, um die ursprüngliche Struktur beizubehalten. Die Datensätze werden dabei so wenig wie möglich verändert und lediglich um einige Metadaten wie Sprache, ID und Timestamps für den nächsten Verarbeitungsschritt angereichert.

### Schritt 2: Transform & Load
Aus der Staging-Datenbank werden die Daten in die Zielstruktur der Core-Datenbank (PostgreSQL) überführt (Load). In diesem Schritt findet die eigentliche **Transformation** und Harmonisierung statt. Für weit verbreitete Datenschnittstellen stehen bereits fertige Importer zur Verfügung, die nur noch für den konkreten Anwendungsfall konfiguriert werden müssen.
