<!-- #	Systemarchitektur
Die technische Basis für dataCycle bildet das Web-Application-Framework „Ruby on Rails“. Da in der dataCycle nicht
nur Daten zu finden sind, die auch innerhalb der dataCycle erstellt worden sind, ist es notwendig, externe Systeme
über einen Import-Prozess anzubinden. Dieser Import-Prozess erfolgt in zwei Schritten, die auch über verschiedene
Datenbanken abgebildet werden. Zuerst werden die Daten in eine Staging-Datenbank importiert, von wo aus sie dann über
eine Datentransformation in die Core-Datenbank übernommen werden.

##	Staging-Datenbank
Im ersten Schritt werden die Daten als Rohdaten in einer MongoDB gespeichert. Dadurch ist es möglich, die Daten in der
ursprünglichen Datenstruktur für genaue Analysen bzw. Fehlersuchen zu verwenden. Ohne diesen Schritt wäre es an
manchen Stellen schwierig, eine genaue Verbindung zwischen den Originaldaten und den transformierten Daten
herzustellen, da sich die Datenstruktur bei der Transformation in die gewünschte Zieldatenstruktur oft sehr stark
verändert. Ein weiterer Vorteil der Staging-Datenbank ist die Möglichkeit bereits an dieser Stelle mit aggregierten
Datensätzen arbeiten zu können. Ein Beispiel dafür ist etwa das Erstellen von Listen mit allen bekannten Werten von
Aufzählungen wie z.B. Tags.

Das Übernehmen der Daten in die Staging-Datenbank wird dabei von der jeweiligen Datenquelle vorgegeben. Das heißt,
dass in der Staging-Datenbank für jeden verfügbaren Daten-Endpunkt eine eigene Collection angelegt wird. Stellt eine
Datenquelle zum Beispiel Kontaktpersonen und Firmen als getrennte Endpunkte zur Verfügung gibt es auch in der
Staging-Datenbank diese beiden separaten Collections. Gibt es eine Möglichkeit, Aufzählungen wie beispielsweise
Kategorien in Form von eigenen Endpunkten abzufragen, so werden auch diese als eigene Collections angelegt.

Beim Speichern der Datensätze in die Datenbank werden die Daten so wenig wie möglich verändert. Stehen die Daten in
Form von JSON-Datensätzen zur Verfügung, können die Daten ohne Veränderung übernommen werden, bei anderen
Datenformaten sind minimale Transformationen notwendig. Bei XML ist es zum Beispiel notwendig, Child-Nodes und
Attribute-Nodes zusammenzuführen, wodurch es aber wiederum zu Namenskonflikten kommen könnte. Aus diesem Grund
müssen hier auch leichte Anpassungen an der Datenstruktur vorgenommen werden, damit die Daten ohne Probleme in der
Staging-Datenbank abgelegt werden können.

Damit der nächste Schritt des Import-Prozesses effizient durchgeführt werden kann, werden die Rohdaten in eine
rudimentäre Basis-Datenstruktur eingebettet und mit ein paar Metadaten angereichert. Eine wichtige Information ist
zum Beispiel die Sprache oder die ID des Datensatzes. Zusätzlich werden noch Timestamps angelegt, damit leicht
ermittelt werden kann, wie aktuell ein Datensatz in der Staging-Datenbank gerade ist.

##	Core-Datenbank
Die Core-Datenbank ist die Basis sowohl für die Verwaltung aller innerhalb des Systems erstellen Inhalte sowie aller
importierten Daten als auch für den Data-Access-Layer, also die externe Datenschnittstelle. Für die Core-Datenbank
wird eine relationale Datenbank, nämlich PostgreSQL verwendet. PostgreSQL ist deshalb im Einsatz, weil es sich zum
einen um eine performante, weit verbreitete und gut etablierte Open-Source-Datenbank handelt. Zum anderen stehen
einige sehr wichtige Funktionen zur Verfügung, wie zum Beispiel die Basisfunktionalität für eine Volltextsuche, die
bei ähnlichen Systemen gar nicht oder nur zum Teil vorhanden sind. Der Import von externen Daten läuft über die
oben beschriebene Staging-Datenbank und wird je nach konkretem Anwendungsfall individuell entwickelt. Für weit
verbreitete bzw. viel genutzte Datenschnittstellen stehen bereits entsprechende Importer bereit, die nur mehr für die
einzelnen Installationen von dataCycle und die konkreten Anwendungsszenarien eingerichtet werden müssen.

In der Core-Datenbank sind auch die wesentlichen Features für das dataCycle zugrundeliegende Redaktionssystem
abgebildet. Diese Funktionen sind im Folgenden kurz beschrieben.

###	Volltextsuche
Eine wichtige Anforderung für die Filterung von Daten innerhalb von dataCycle ist die Volltextsuche. Dabei
müssen einige sehr unterschiedliche Dinge berücksichtigt und miteinander kombiniert werden. PostgreSQL bietet hier
zwar bereits sehr viel Basisfunktionalität, es ist aber dennoch notwendig, noch eine weitere Abstraktionsebene
einzuziehen. Eine Herausforderung ist beispielsweise das Kombinieren von Daten mit unterschiedlichen Basis-Datentypen.
Außerdem ist es oft notwendig, unterschiedliche Datentypen mit einer unterschiedlichen Gewichtung zu versehen, um eine
priorisierte Sortierreihenfolge zu ermöglichen. Zusätzlich dazu müssen auch Klassifizierungen bei der Volltextsuche
mitberücksichtigt werden. Um diese Herausforderungen möglichst gut zu bewältigen, gibt es spezielle Tabellen, die alle
relevanten Daten aller Basisdatentypen in einer für die Volltextsuche optimierten Form zusammenfassen. Eine wichtige
Information, die an dieser Stelle für jeden einzelnen Datensatz hinterlegt ist, ist ein sogenannter Boost. Dieser
Boost wird verwendet, um die Reihenfolge, die standardmäßig auf Basis der Relevanz eines Suchergebnisses erstellt
wird, noch weiter zu verfeinern. Der Boost wird dabei als zusätzliche Gewichtung verwendet, die mit der normalen
Gewichtungsfunktion für die Sortierreihenfolge multipliziert wird. Ergebnisse mit einem höheren Boot werden dabei
entsprechend vorgereiht.

###	Change-Tracking
Besonders für innerhalb von dataCycle angelegte Kreativ-Daten ist es oft notwendig, die Änderungen eines
Datensatzes genau nachverfolgen zu können. Damit kann zum Beispiel im Nachhinein festgestellt werden, von welchem
Benutzer welche Anpassungen vorgenommen worden sind, wenn mehrere unterschiedliche Benutzer an ein und demselben
Datensatz arbeiten. Um das zu ermöglichen wird innerhalb der Core-Datenbank die komplette Historie eines Datensatzes
gespeichert, es werden also alle Version ab der Erstellung in der Datenbank abgelegt. Damit der Zugriff auf die
aktuellen Daten durch die historischen Daten nicht unnötig verlangsamt wird, werden die historischen Daten in eigenes
dafür vorgesehen Tabellen abgelegt. Über diesen Mechanismus ist es auch möglich, nachzuverfolgen, welche Inhalte von
welchem Benutzer zu welchem Zeitpunkt gelöscht worden sind. Es kommt in der Praxis immer wieder vor, dass Inhalte
unabsichtlich gelöscht werden und in diesen Fällen ist es sehr hilfreich, herauszufinden, durch welchen Benutzer
dieser Vorgang ausgelöst worden sind. -->
