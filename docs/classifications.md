# Klassifizierungen

Eine sehr wesentliche Komponente von dataCycle ist das Klassifizierungssystem. Es dient dazu, Inhalte in unterschiedliche Schubladen einzuteilen. Häufig spricht man in diesem Zusammenhang von Kategorien oder Tags, die mit einem Inhalt verknüpft werden können. Der Unterschied zwischen Kategorien und Tags besteht darin, dass Kategorien in Form eines Baumes organisiert sind und Tags in einer flachen Liste. Bei Kategorien besteht also die Möglichkeit einer sogenannten _Überkategorie_ beliebig viele _Unterkategorien_ hinzuzufügen, vergleichbar mit einer Ordnerstruktur innerhalb eines Dateisystems. Durch Klassifizierungen lassen sich sowohl Kategorien als auch Tags innerhalb von dataCycle über die gleiche Systematik abbilden.

Ein wesentlicher Aspekt bei der Verwendung von Klassifizierungen ist, dass ein einziger Inhalt häufig nicht nur in Schubladen innerhalb eines einzigen "Kästchens" gesteckt werden soll, sondern dass ein Inhalt in unterschiedliche Schubladen in verschiedenen "Kästchen" eingeordnet werden muss. Ein Mensch kann dabei zum einen über die Schubladen _männlich_ und _weiblich_ im Kästchen _Geschlecht_ klassifiziert werden, andererseits kann aber auch das Kästchen _Haarfarbe_ mit den Klassifizierungen _blond_, _rot_, _braun_ und _schwarz_ herangezogen werden. Aus diesem Grund können in dataCycle beliebig viele unabhängige Klassifizierungsbäume erstellt und verwaltet werden. Diese Klassifizierungsbäume können in weiterer Folge für die Kategorisierung bzw. das Taggen von Inhalten verwendet werden, es ist dabei möglich Klassifizierungen aus mehreren Klassifizierungsbäumen mit einem Inhalt zu verknüpfen. Dadurch ergibt sich ein multidimensionales Klassifizierungssytem, über das auch komplexe Szenarien abgebildet werden können.

## Klassifizierungsmapping

dataCycle bietet die Möglichkeit, Inhalte nicht nur originär in dataCycle zu erstellen, sondern auch über unterschiedliche Import-Schnittstellen von anderen Systemen zu übernehmen. Dadurch ergeben sich Situationen, in denen gleiche bzw. sehr ähnliche Arten von Inhalten aus unterschiedlichen Datenquellen importiert werden, die zwar im Grunde die gleichen Klassifizierungsbäume verwenden, allerdings mit leicht unterschiedlichen Bezeichnungen für die an sich gleichen oder nur leicht unterschiedlichen Klassifizierungen. Ein System verwendet für die Einteilung der _Haarfarbe_ zum Beispiel _braunhaarig_, ein anderes System verwendet stattdessen aber den Begriff _brünett_.

Um genau diese Unterschiede auflösen zu können, bietet dataCycle einen speziellen Mechanismus, ein sogenanntes Klassifizierungsmapping, an. Im Wesentlichen gibt es damit in dataCycle eine Möglichkeit einen vereinheitlichten, systemübergreifenden Klassifizierungsbaum zu erstellen, auf den die importierten Klassifizierungsbäume abgebildet werden können. Im Falle des vorhergehenden Beispiels mit den Haarfarben könnte ein neuer dataCycle-interner Klassifizierungsbaum mit den Klassifizierungen _blond_, _braun_, usw. erstellt werden, wobei die Klassifizierung _braun_ als Alias für die beiden Klassifizierungen _braunhaarig_ und _brünett_ dienen würde (siehe dazu die Grafik "Klassifizierungsmapping").

![Klassifizierungsmapping](images/classification_mapping.svg 'Klassifizierungsmapping')

## Sichtbarkeit von Klassifizierungsbäumen

Durch die weitreichenden Möglichkeiten in Bezug auf Klassifizierungen innerhalb von dataCycle kann die Anzahl der mit einem Inhalt verknüpften Klassifizierungen sehr leicht sehr groß werden. Um trotzdem eine möglichst gute Übersichtlichkeit zu gewährleisten, können die einzelnen Klassifizierungsbäume in verschiedenen Bereichen des dataCycle-Backends ein- bzw. ausgeblendet werden. Es stehen dazu in der Klassifizierungsadministration die folgenden Bereiche zur Verfügung:

- __Detailansicht__: Klassifizierungen werden in der Detailansicht direkt im Header angezeigt

- __Detailansicht__ (standardmäßig eingeklappt): Klassifizierungen werden im Header der Detailansicht versteckt und können über "weitere Klassifizierungen" angezeigt werden

- __Bearbeitungsansicht__: Klassifizierungen werden in der Bearbeitungsansicht angezeigt

- __API__: Klassifizierungen werden über die API ausgeliefert

- __Kachel__: Klassifizierungen werden in der Kachel-Ansicht von Inhalten (z.B. am Dashboard) angezeigt

Durch die Möglichkeit, Klassifizierungen in unterschiedlichen Bereichen ein- bzw. auszublenden, kann die Anzahl der angezeigten Klassifizierungen in den unterschiedlichen Bereichen optimal auf die spezifischen Anforderungen angepasst und die einzelnen Bereiche damit entsprechend übersichtlich gestaltet werden. Sind einzelne Klassifizierungsbäume, die beispielsweise von einem externen System importiert und über das Klassifizierungsmapping vereinheitlicht werden, am Dashboard nicht notwendig, können diese für den Bereich _Kachel_ - also die am Dashboard verwendete Ansicht für Inhalte - ausgeblendet werden.
