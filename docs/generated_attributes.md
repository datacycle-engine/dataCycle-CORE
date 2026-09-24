# Maschinell gefüllte Attribute (`_generated`)

## Übersicht

Ein Attribut, das eine Maschine füllt, steht **neben** dem redaktionellen und nicht an seiner
Stelle: `description_generated` neben `description`. Beide werden in der Datenschnittstelle als
dasselbe Feld ausgespielt, und der redaktionelle Wert gewinnt. Damit bleibt ein generierter Wert
gespeichert, während er nicht wirksam ist, und wird wieder wirksam, sobald das redaktionelle Feld
leer ist — ohne neue, kostenpflichtige Anfrage.

Ein Template deklariert nur das Companion-Attribut. Alles andere leitet
`MasterData::Templates::Extensions::Generated` aus dem Namen ab, wie die Overlays ihre
`_override`/`_add`/`_overlay`-Geschwister aus `:overlay: true`.

## Namenskonvention

Ein Attribut gilt als Companion, wenn

1. sein Name auf `_generated` endet und
2. das Attribut ohne dieses Postfix im selben Template existiert.

Fehlt das Basisattribut, ist das ein Konfigurationsfehler: der Template-Import meldet
`base attribute '<name>' missing for the _generated convention` und importiert das Template nicht.
`contributor_generated` ist von der Erkennung ausgenommen — es ist die injizierte Kennzeichnung
(siehe unten) und kein Companion.

## Was ein Template deklariert

```yaml
:description_generated:
  :label: Beschreibung (ALT-Label, automatisch generiert)
  :type: string
  :storage_location: translated_value
  :local: true # kein Import, kein Import-Reset
  :visible: [show, api]
  :position:
    :before: description # tragend: der redaktionelle Wert gewinnt in der API
  :api:
    :name: description
  :compute:
    :module: Datacycle::Feature::Embedding::Utility::Compute
    :method: annotation_text
    :fallback: false # ein leeres Ergebnis darf den alten Wert nicht wiederherstellen
    :parameters:
      - virtual_web_url
      - content_url
```

`:position: :before:` ist keine Kosmetik: die Serialisierung überspringt leere Werte, und nur weil
das Companion-Attribut zuerst geschrieben wird, überschreibt der redaktionelle Wert es danach.

## Was der TemplateTransformer ergänzt

`MasterData::Templates::Extensions::Generated` leitet den Rest aus dem Namen ab; ein Template
deklariert nichts davon, und die Begründung je injizierter Zeile steht an der Klasse:

- am Companion-Attribut die Marker `features.generated.generated_for` und
  `features.generated.blocked_by`, je blockierendem Attribut eine `compute.condition` mit
  `not_exists?` — an eine bereits deklarierte Bedingung angehängt, nicht an ihre Stelle — und
  `compute.async: true`, sofern das Template nicht `after_save: true` deklariert;
- am Template, einmal, das verlinkte Attribut `contributor_generated` auf
  `ArtificialIntelligenceAgent`. Die Kennzeichnung wird unter `contributor` an die bestehenden
  Mitwirkenden angehängt, nicht daneben ausgespielt, und das nur in v4: die
  `append`-Transformation ist ausschließlich in den v4-Partials implementiert, unter v2/v3 wäre
  daraus ein eigener Key `contributorGenerated` geworden.

`blocked_by` nennt das Basisattribut und, wo dieses ein Overlay trägt, dessen `_override` — die
beiden redaktionellen Attribute, die leer sein müssen, damit generiert wird. Nicht
`<Basisattribut>_overlay`, obwohl genau das der ausgespielte Wert ist: dieses Attribut ist virtuell,
wird also beim Lesen gerechnet und nie geschrieben, und eine Bedingung darauf könnte von keinem
Speichern je eingeplant werden.

Ändert sich ein blockierendes Attribut, wird das Companion-Attribut zusätzlich in allen *übrigen*
Sprachen neu gerechnet (`DataHash#generated_companions_to_recompute`); was eine Sprache dann
tatsächlich zu tun hat, entscheidet die injizierte Bedingung.

## Der Erzeuger: Hook `ai_agents_for`

`Utility::Compute::Generated#ai_agents` ermittelt je Companion-Attribut die Sprachen, in denen der
generierte Wert wirksam ist (Basisattribut leer, Companion gefüllt), und fragt dann das
Compute-Modul des Companion-Attributs:

```ruby
# @param content [DataCycleCore::Thing]
# @param key [String] Companion-Attribut
# @param locales [Array<String>] Sprachen, in denen der generierte Wert wirksam ist
# @return [Array<DataCycleCore::Generic::Common::DataReferenceTransformations::AiAgentReference>]
def ai_agents_for(content, key, locales)
end
```

Ohne Hook bekommt der Inhalt den Sammel-Agenten, den `AiAgentService` standardmäßig anlegt
(„KI-Agent"), mit dem Grad `odta:AIInvolved` — „Eine KI war am Entstehungsprozess dieses Inhalts
beteiligt". `odta:AIGenerated` wäre am Bild die falsche Aussage, weil das Bild selbst nicht
KI-generiert ist; ein Erzeuger, der wirklich den Inhalt erzeugt, gibt den Grad über denselben Hook
zurück. Wer nur den Agenten benennen will, lässt den Grad leer und bekommt denselben Standard —
`AiAgentService` verwirft eine Referenz, deren Grad kein Concept trifft, ohne Fehlermeldung.

Die Kennzeichnung hängt am Inhalt, nicht an der einzelnen Übersetzung: eine wirksame Sprache
genügt, und mehrere Companion-Attribute mit verschiedenen Compute-Modulen an einem Inhalt ergeben
mehrere Agenten.

Ist der Grad im Baum `ODTA - AI-DegreeOfInvolvement` nicht vorhanden oder fehlt das Template
`ArtificialIntelligenceAgent`, bleibt die Kennzeichnung aus; der generierte Wert wird trotzdem
gespeichert und ausgespielt.

## Filtern im Dashboard

Die Kennzeichnung ist eine Relation in `content_content_links`, also deckt der bestehende
`graph_filter` sie ab — ein eigener `relation_filter`-Eintrag ist nicht nötig. Die Attributsliste des
Filters kommt aus `Feature::AdvancedFilter.graph_filter_relations`, also aus den tatsächlich
vorhandenen Relationen: `contributor_generated` erscheint dort, sobald die erste Kennzeichnung
geschrieben ist.

- „Verlinkte Inhalte in" → `contributor_generated` → *vorhanden* / *nicht vorhanden* beantwortet
  „hat KI-generierte Felder".
- derselbe Filter mit *gleich* und einem konkreten KI-Agenten trennt die Erzeuger.

Companion-Attribute an embedded Inhalten sind so nicht filterbar: `graph_filter_relations_query`
schließt Links aus, deren Inhalt embedded ist. Kennzeichnung und API-Ausspielung funktionieren
trotzdem, gefiltert wird auf Ebene des Haupt-Inhalts.

## Bestandsdaten nachkennzeichnen

```
bundle exec rails dc:update
bundle exec rake dc:update_data:computed_attributes['Bild','false','contributor_generated']
```

Erst `dc:update`, damit die injizierten Attribute in der Datenbank stehen. Der Backfill läuft vor
der ersten Filterverwendung: solange keine `contributor_generated`-Links existieren, steht die
Relation im Attributs-Dropdown nicht zur Auswahl. Sprachen, die es am Inhalt nicht gibt, werden
nicht gerechnet — `update_computed_values` läuft nur über `available_locales`.

## Abschalten und Aufräumen

Was einen generierten Wert löscht, ist nicht eine eigene Aufräum-Aufgabe, sondern der Erzeuger
selbst: antwortet er mit nichts, verbietet `:fallback: false` das Wiederherstellen des
gespeicherten Werts, und der nächste Lauf schreibt leer. Die Kennzeichnung folgt, weil
`contributor_generated` dann keine wirksame Sprache mehr findet. Beides deckt
`test/models/content/attributes/computed_generated_test.rb` ab („a producer that no longer
generates clears the value and the marking").

**Bestände löschen** heißt also: den Erzeuger für diese Inhalte stumm schalten, dann denselben
Backfill laufen lassen.

```
bundle exec rake dc:update_data:computed_attributes['ImageObject','false','description_generated|contributor_generated']
```

Beim `imageDescriptionPixie` ist der Schalter `:generate_for: :external_sources:` in der
`features.yml` des Projekts — er muss auf etwas zeigen, das kein Inhalt trägt. **Eine leere oder
fehlende Liste schaltet nicht ab, sondern generiert für jedes Bild**
(`Feature::ImageDescriptionPixie#generate?` antwortet dann `true`). `:allowed: false` am Feature
hilft ebenfalls nicht: das `:features:`-Block des Attributs im Template wird danach
einkonfiguriert und gewinnt. Bleibt `:enabled: false`, was auch die redaktionellen Buttons
entfernt.

Ein redaktioneller **Override** wirkt wie ein redaktioneller Basiswert: die Generierung hält an und
die Kennzeichnung entfällt, solange er steht; der bereits generierte Wert bleibt gespeichert und
wird nur nicht mehr ausgespielt. Wird der Override entfernt, rechnet der Compute wieder — dass das
keine neue, kostenpflichtige Anfrage auslöst, ist Sache des Erzeugers und nicht dieses Mechanismus:
der `imageDescriptionPixie` liest die gespeicherte Annotation der Zeile in `embeddings` und fragt
den Dienst nur, wenn sie die Sprache nicht beantworten kann. Ein Erzeuger ohne eigenen Zwischenspeicher
zahlt erneut. Abgedeckt in `test/models/content/attributes/computed_generated_test.rb` („an override
ends the generation and the marking, and removing it brings both back").

**Bestände behalten und nur nichts Neues generieren** geht so nicht: derselbe Mechanismus löscht
sie beim nächsten Recompute. Wer die Texte behalten will, hebt sie vorher ins redaktionelle
Attribut (einmalige Data-Migration, nur wo dieses leer ist). Sie gelten damit als redaktionell und
verlieren die KI-Kennzeichnung — was über sie zu behaupten dann die falsche Aussage sein kann.

## Wechsel des Erzeugers

Wird ein Companion-Attribut auf einen anderen Dienst umgestellt, passiert an Bestandsinhalten
zunächst nichts: die Konfigurationsänderung allein plant keinen Recompute ein. Sobald aber etwas
einen auslöst — ein Import, der eine Abhängigkeit ändert, eine Redaktion, die das Basisattribut
leert, oder der Backfill —, wird der Inhalt vom neuen Dienst neu annotiert. Beim
`imageDescriptionPixie` liegt die gespeicherte Annotation je externem System
(`Datacycle::Feature::Embedding::Base.stored_annotation`), der neue Dienst sieht also keine und
fragt kostenpflichtig neu an; die alte Zeile bleibt erhalten, ein Rückwechsel kostet nichts.

Die Kennzeichnung sammelt dabei nicht: `contributor_generated` wird mit `:fallback: false`
gerechnet, der Lauf speichert genau die aktuell wirksamen Agenten, und der vorherige Dienst
verschwindet. Abgedeckt in `test/models/utility/compute/generated_test.rb` („a producer that
changes its agent replaces the marking instead of adding to it") und in
`test/models/content/attributes/computed_generated_test.rb` („a stale agent is replaced by the next
recompute rather than kept alongside").
