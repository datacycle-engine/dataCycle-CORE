<!-- #	Datenstruktur
Die grundsätzlichen Datenstrukturen für in dataCycle abgelegte Inhalte orientieren sich stark an den Vorgaben von
[schema.org](https://schema.org/), Erweiterungen bzw. Änderungen gibt es nur in Ausnahmefällen.

##	Elementare Datentypen
Ein konkreter Inhaltstyp in dataCycle, wie beispielsweise ein Artikel oder ein POI kann aus unterschiedlichen
elementaren Datentypen aufgebaut werden. Diese elementaren Datentypen beinhalten die eigentlichen Inhalte dataCycle.

###	Text
Da sich Texte in dataCycle durch die angebotenen Möglichkeiten zur Formatierung unterscheiden, gibt es in dataCycle
mehrere unterschiedliche Datentypen für diesen Zweck. Die einzelnen Datentypen unterscheiden sich dabei nur durch die
angebotenen Formatierungsmöglichkeiten, die im Front-End zur Verfügung stehen, um zum Beispiel Listen innerhalb von
Überschrift von vornherein auszuschließen.
Eine Einschränkung, die für alle textuellen Inhalte gelten kann, falls das beim jeweiligen Inhaltstyp so vorgesehen
und auch entsprechend konfiguriert ist, betrifft die Länge eines Textes. Es kann sowohl eine Mindest- als auch eine
Maximallänge für ein Text-Feld definiert werden.
Damit die Arbeit für Benutzer vereinfacht wird, gibt es bei allen Text-Feldern eine Information über die Anzahl der
bereits eingegebenen Zeichen und Wörter.

#### Text ohne Formatierung (z.B. für SEO-Keywords, Social-Media-Text, ...)
Inhalte dieses Datentyps werden ohne Formatierungen in dataCycle abgelegt. Wird der Text via Copy&Paste in die
Datenbank eingefügt, werden bestehende Formatierungen vollständig entfernt.

#### Text mit grundlegenden Formatierungsmöglichkeiten (z.B. für Überschriften)
Bei diesem Element sind nur rudimentäre Formatierungen (fett, kursiv) erlaubt. Formatierungen, die über diese
Möglichkeiten hinausgehen, werden beim Speichern automatisch entfernt und nicht in dataCycle gespeichert.

#### Text mit erweiterten Formatierungsmöglichkeiten (z.B. für Fließtext)
Dieses Text-Element erlaubt weitgehende Formatierungsmöglichkeiten, so können hier zusätzlich zu den einfachen
Auszeichnungen von Texten mittels fett und kursiv auch Listen bzw. Aufzählungen aber auch Links hinzugefügt werden.
Nicht unterstützte Formatierungs-Elemente (z.B. Schriftgrößen) werden aber auch hier beim Speichern entfernt und nicht
in dataCycle gespeichert.

### Referenzen

###	Zeitraum
Die Angabe von Zeiträumen erfolgt durch die Eingabe eines Start- und eines End-Zeitpunkts. Zeiträume kommen zum
Beispiel bei Veranstaltungen oder beim Gültigkeitszeitraum zum Einsatz.

###	Kategoriezuordnung
Bei vielen Inhalten ergibt es Sinn diese Inhalte auf Basis von unterschiedlichen Klassifizierungsbäumen zu
kategorisieren. Bei POIs zum Beispiel kann es hilfreich sein, diese einer oder mehreren Jahreszeiten zuordnen zu
können, um auf diese Weise festzulegen, für welchen Zeiträume diese POIs geeignet sind. Ein Datensatz kann dabei so
konfiguriert werden, dass ein Datenfeld die einfache oder mehrfache Auswahl einer bzw. mehrerer Klassifizierungen
eines dafür vorgesehenen Klassifizierungsbaumes erlaubt.

###	Verschachtelte Datensätze
Ein weiterer Datentyp, der in dataCycle verwendet werden kann, ist ein sogenannter verschachtelter Datensatz. Dieser
Datentyp dient in ersterer Linie einer klaren Strukturierung der Daten, auch im Sinne von [schema.org]
(https://schema.org/). Ein verschalter Datensatz kann dabei wiederum aus anderen elementaren Datentypen aufgebaut
werden. Ein einfacher Anwendungsfall für einen verschachtelten Datensatz ist zum Beispiel ein Zitat, das wiederum aus
einem Text, einem Bild und einem Autor bestehen kann. An dieser Stelle ergibt es Sinn, diese Daten nicht innerhalb
eines einzigen Textfeldes abzulegen, sondern sie stattdessen in separaten Datenfelder zu erfassen und die Felder für
die Auslieferung über die Schnittstelle gemäß [schema.org](https://schema.org/) zu benennen. -->
