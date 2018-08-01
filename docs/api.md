# Datenschnittstelle

Der Zugriff über die Datenschnittstelle erfolgt immer eine gespeicherte Suche. Grund dafür ist, dass Inhalte dadurch auch im Nachhinein noch jederzeit eingeschränkt werden können. Dazu muss lediglich die gespeicherte Suche entsprechend angepasst werden.

## Authentifizierung

Die Authentifizierung erfolgt über ein sogenanntes _Authentifzierungs-Token_, dass beim Aufruf eines Daten-Endpunktes mit übergeben werden muss. Ist ein Benutzer bereits über das Frontend eingeloggt, kann das Token weggelassen werden, da in diesem Fall bereits eine aktive Session existiert und diese auch für die API weiter verwendet werden kann. Eine Übersicht über alle in einem System vorhandenen Klassifizierungbäume erhält man beispielsweise über [/api/v2/classification_trees?token=MY_TOKEN](/api/v2/classification_trees).
