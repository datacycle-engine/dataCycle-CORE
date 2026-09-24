# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Unit-level coverage of SchemaController's expected-type chip icons (#50201
  # follow-up). A chip that links to a real dataCycle template renders dataCycle's
  # own type icon ("fa dc-type-icon thing-icon <template_name>"), driven by
  # modules/components/_icons.scss — so an icon newly configured for a template
  # appears here automatically, with the default thing glyph as fallback. Shared
  # schema.org types match by name via SCHEMA_TYPE_ICONS; every other kind uses
  # dataCycle's native property-icon classes (SCHEMA_KIND_DC_ICONS), else the
  # property-icon default. Pure — no HTTP/auth/DB needed, like OpenApiViewerControllerTest.
  class SchemaControllerIconsTest < ActiveSupport::TestCase
    def controller
      @controller ||= DataCycleCore::SchemaController.new
    end

    def icon_for(descriptor)
      controller.send(:schema_type_icon, descriptor)
    end

    # ---- template links: dataCycle's own type-icon vocabulary (_icons.scss) ----

    test 'a template-link descriptor renders dataCycle\'s dc-type-icon, keyed by template name' do
      # the chip uses the same markup as the rest of dataCycle, so an icon newly
      # configured for the template in _icons.scss shows up here automatically.
      descriptor = { label: 'ImageObject', kind: :reference, template: 'ImageObject' }

      assert_equal 'fa dc-type-icon thing-icon image_object', icon_for(descriptor)
    end

    test 'the template icon class is keyed by template_name via underscore_blanks (== Thing#icon_type)' do
      descriptor = { label: 'Ski Slope', kind: :reference, template: 'Ski Slope' }

      assert_equal 'fa dc-type-icon thing-icon ski_slope', icon_for(descriptor)
    end

    test 'distinct templates get distinct icon classes (CSS then resolves the glyph)' do
      image = icon_for({ label: 'ImageObject', kind: :reference, template: 'ImageObject' })
      video = icon_for({ label: 'VideoObject', kind: :reference, template: 'VideoObject' })
      person = icon_for({ label: 'Person', kind: :reference, template: 'Person' })

      assert_equal 3, [image, video, person].uniq.size, 'each template maps to its own icon class'
    end

    test 'a template without a dedicated icon still gets the dc-type-icon class (CSS default glyph)' do
      # no hardcoded Ruby fallback — _icons.scss provides the default .thing-icon glyph
      icon = icon_for({ label: 'SomeCustomTemplate', kind: :reference, template: 'SomeCustomTemplate' })

      assert_equal 'fa dc-type-icon thing-icon some_custom_template', icon
    end

    # ---- property kinds: dataCycle's native property-icon classes (CSS-driven) ----

    test 'every mapped kind renders dataCycle\'s native property-icon class (no hardcoded fa-glyph)' do
      DataCycleCore::SchemaController::SCHEMA_KIND_DC_ICONS.each do |kind, classes|
        assert_equal "fa dc-type-icon property-icon #{classes}", icon_for({ label: kind.to_s, kind: })
      end
    end

    test 'the scalar/literal kinds now use native classes instead of the ? default' do
      {
        text: 'type-string', url: 'type-string type-string-url', integer: 'type-number',
        number: 'type-number', boolean: 'type-boolean', geo: 'type-geographic',
        datetime: 'type-datetime', date: 'type-date', concept: 'type-classification'
      }.each do |kind, classes|
        assert_equal "fa dc-type-icon property-icon #{classes}", icon_for({ label: kind.to_s, kind: })
      end
    end

    test 'a standalone reference (EntityReference) uses dataCycle\'s native linked-type icon class' do
      # EntityReference/CollectionReference denote a linked entity, not a primitive —
      # the chip renders dataCycle's own property-icon (type-linked), so the glyph is
      # CSS-driven like the start-page icons, not a hardcoded Font Awesome name.
      assert_equal 'fa dc-type-icon property-icon type-linked', icon_for({ label: 'EntityReference', kind: :reference })
    end

    test 'an unmapped kind falls back to the bare property-icon (its CSS default glyph)' do
      # No type-* class → _icons.scss .property-icon default (question-circle, \f059).
      assert_equal 'fa dc-type-icon property-icon', icon_for({ label: 'Mystery', kind: :something_new })
    end

    # ---- shape: always a usable icon class ----

    test 'every icon is a usable fa or dc-type-icon class' do
      [
        { label: 'ImageObject', kind: :reference, template: 'ImageObject' }, # template link  → dc-type-icon thing-icon
        { label: 'EntityReference', kind: :reference },                      # linked wrapper → dc-type-icon property-icon
        { label: 'GeoCoordinates', kind: :shared },                          # shared type    → fa fa-*
        { label: 'DateTime', kind: :datetime },                              # literal        → dc-type-icon property-icon
        { label: 'URL', kind: :url },                                        # literal (two type-* classes)
        { label: 'Text', kind: :text }
      ].each do |descriptor|
        assert_match(/\Afa (fa-[a-z0-9-]+|dc-type-icon (thing|property)-icon [a-z0-9_ -]+)\z/, icon_for(descriptor))
      end
    end

    # ---- schema_template_icon still resolves via the same matcher ----

    test 'schema_template_icon derives from schema_name + template_name' do
      template = Struct.new(:schema_name, :template_name).new(['ImageObject'], 'Bild')

      assert_equal controller.send(:icon_for_schema_name, 'ImageObject Bild'),
                   controller.send(:schema_template_icon, template)
    end
    # ---- card icons: the template's own name outranks its ancestor chain ------
    # SCHEMA_TYPE_ICONS is a hand-kept regex list, and both of its failure modes
    # are silent: a keyword from an ancestor beating the template's own type, and a
    # keyword matching inside another word. Both are covered here.

    def card_icon(template_name, schema_name = [])
      controller.send(
        :schema_template_icon,
        Struct.new(:template_name, :schema_name).new(template_name, schema_name)
      )
    end

    test 'a template whose name starts with its type gets that type\'s icon, not an ancestor\'s' do
      # the regression: "EventDescription" is a CreativeWork/Article descendant, and
      # matching the joined chain first handed it the text-document icon
      assert_equal 'ticket', card_icon('EventDescription', ['CreativeWork', 'Article'])
      assert_equal 'ticket', card_icon('Event', ['Event'])
      assert_equal 'calendar-o', card_icon('EventSeries', ['Event'])
    end

    test 'a keyword only counts as a whole word, not as a substring of another' do
      # /description/ must not fire on "EventDescription" …
      assert_equal 'ticket', card_icon('EventDescription')
      # … while a name that really is a description still matches
      assert_equal 'file-text-o', card_icon('Description')
    end

    test 'CamelCase names are split into words before matching' do
      assert_equal 'picture-o', card_icon('ImageObject')
      assert_equal 'map-marker', card_icon('PostalAddress')
      assert_equal 'file-o', card_icon('MediaObject')
      assert_equal 'globe', card_icon('WebPage')
    end

    test 'the ancestor chain decides only when the template name matches nothing' do
      assert_equal 'map-marker', card_icon('Skigebiet', ['Place', 'LandmarksOrHistoricalBuildings'])
      assert_equal DataCycleCore::SchemaController::DEFAULT_SCHEMA_ICON, card_icon('Skigebiet')
    end
  end
end
