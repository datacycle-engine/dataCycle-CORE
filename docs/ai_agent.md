# Kennzeichnung der KI-Beteiligung (KI-Agent)

## Übersicht

Art. 50 der EU-KI-Verordnung verlangt ab 02.08.2026, dass Inhalte gekennzeichnet sind, an denen eine KI beteiligt war. In dataCycle trägt diese Kennzeichnung ein eigener Inhaltstyp: der **KI-Agent** (`ArtificialIntelligenceAgent`). Er wird beim Inhalt unter **Mitwirkende** verknüpft und bringt den Grad der KI-Beteiligung mit.

Ein KI-Agent ist ein eigener Inhalt, auf den beliebig viele andere Inhalte verweisen. Für den Regelfall genügt ein Agent je Beteiligungsgrad. Ein weiterer kommt nur dazu, wenn das eingesetzte KI-Tool benannt werden soll.

## Beteiligungsgrade

Die Beteiligungsgrade kommen aus dem Klassifizierungsbaum **ODTA - AI-DegreeOfInvolvement**. Jeder KI-Agent trägt genau einen davon. Für zwei Grade braucht es also zwei Agenten.

| Grad | Bedeutung | URI |
| --- | --- | --- |
| KI-unterstützt | Eine KI war am Entstehungsprozess dieses Inhalts beteiligt. | `odta:AIInvolved` |
| KI-generiert | Dieser Inhalt wurde von einer KI erzeugt. | `odta:AIGenerated` |
| KI-bearbeitet | Dieser Inhalt wurde von einer KI wesentlich bearbeitet. | `odta:AIModified` |

## Betroffene Inhaltstypen

Gekennzeichnet werden können alle Inhalte mit dem Feld **Mitwirkende**:

- Medien: Bild, Video, Audio, PDF und die übrigen MediaObject-Typen
- Creative Works, z.B. Artikel
- Zusatzinformationen

Bei der Webcam ist das Feld ausgeblendet. Beim Video ist **Mitwirkende** das frühere Feld "Kamera", das jetzt zusätzlich Organisation und KI-Agent aufnimmt.

## KI-Agenten an einem Inhalt verknüpfen

1. Inhalt bearbeiten
2. Bei **Mitwirkende** suchen und den passenden KI-Agenten auswählen. Das Feld nimmt auch Person und Organisation, und mehrere Einträge gleichzeitig
3. Speichern

Das Feld **Grad der KI-Beteiligung** am Inhalt füllt sich beim Speichern automatisch aus den verknüpften KI-Agenten und ist nicht direkt bearbeitbar. Es steht im Kopfbereich der Detailansicht und lässt sich wie jede andere Klassifizierung filtern. Sind mehrere KI-Agenten verknüpft, werden alle ihre Grade angezeigt. Werden alle KI-Agenten entfernt, ist das Feld nach dem Speichern wieder leer.

## Einen neuen KI-Agenten anlegen

Zuerst kontrollieren, ob ein entsprechender KI-Agent bereits existiert. Importe legen KI-Agenten selbst an, und ein zweiter Agent mit demselben Titel und Grad ist eine Dublette.

Neuer Inhalt → Inhaltstyp `KI-Agent`. Der Dialog fragt zwei Felder:

| Feld | Bedeutung |
| --- | --- |
| **Titel** | Freier Text, übersetzbar. Sinnvoll ist der Name des Werkzeugs, etwa "Midjourney". Wenn das Werkzeug keine Rolle spielt, reicht der Sammel-Agent "KI-Agent". |
| **Grad der KI-Beteiligung** | Pflichtfeld, genau ein Wert aus der Tabelle oben. |
| **Beschreibung** | Nicht bearbeitbar, wird aus dem Grad berechnet: der Name des Grades, pro Sprache übersetzt ("KI-generiert" / "AI generated"). |

Sind Inhaltspools aktiv, wird ein KI-Agent im voreingestellten Inhaltspool angelegt und taucht damit in den Standardfiltern des Dashboards auf.

## Importierte Inhalte

Importer, deren Quelle die KI-Kennzeichnung mitliefert (feratel Deskline, Contwise), legen den passenden KI-Agenten bei Bedarf selbst an und verknüpfen ihn bei den Mitwirkenden. Dort ist nichts zu tun. Diese Agenten heißen standardmäßig "KI-Agent", außer die Quelle liefert einen eigenen Namen mit.

## Pixie-generierte Felder

Felder, die ein Pixie automatisch füllt, kennzeichnet dataCycle selbst. Sie liegen in einem eigenen
Attribut neben dem redaktionellen — das ALT-Label eines Bildes etwa in **Beschreibung (ALT-Label,
automatisch generiert)** neben **Beschreibung** — und die Kennzeichnung hängt daran: solange der
generierte Wert wirksam ist, also das redaktionelle Feld leer ist, trägt der Inhalt den passenden
KI-Agenten unter **Mitwirkende**. Wird das redaktionelle Feld gefüllt, verschwindet die
Kennzeichnung beim Speichern; wird es wieder geleert, ist sie zurück. Hier ist nichts zu tun, und
die Agenten legt dataCycle bei Bedarf selbst an.

Eines unterscheidet sich von der manuellen Verknüpfung:

- **Automatischer Lauf gegen Generieren-Button.** Der automatische Lauf greift nur, wo das
  redaktionelle Feld leer ist, und kennzeichnet den Inhalt. Der Generieren-Button dagegen schreibt
  einen Vorschlag in die Bearbeitungsansicht, der erst mit dem Speichern wirksam wird — und zwar im
  redaktionellen Feld. Ein so gespeicherter Text ist eine redaktionelle Bearbeitung.

Gefiltert wird über den bestehenden Filter **Verlinkte Inhalte in** mit dem Attribut
**KI-Mitwirkende**: der Modus *vorhanden* findet alle Inhalte mit KI-generierten Feldern, der
Modus *gleich* mit einem konkreten KI-Agenten trennt die Erzeuger. Der Mechanismus dahinter steht in
`docs/generated_attributes.md`.

## Datenschnittstelle

Über die Datenschnittstelle kommt die Kennzeichnung beim verknüpften KI-Agenten: unter `contributor`, dort der Grad als `odta:aiDegreeOfInvolvement` mit der URI der Klassifizierung (`odta:AIGenerated`). Am Inhalt selbst wird der Grad standardmäßig über `dc:classification` ausgespielt, wie jede Klassifizierung aus einem für die Datenschnittstelle sichtbaren Baum. Ein eigenes Feld **Grad der KI-Beteiligung** gibt es in der Antwort nicht.
