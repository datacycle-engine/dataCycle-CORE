# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module OpenApi
    # Tests DataCycleCore::OpenApi::EntityBuilder: the component-name sanitizer,
    # the structural invariants of a built entity schema, that the builder is
    # robust across every ThingTemplate of the instance, and that it honours the
    # requested locale instead of the ambient one (no hardcoded language).
    class EntityBuilderTest < DataCycleCore::TestCases::ActiveSupportTestCase
      # --- component_name (pure, no DB) ------------------------------------

      test 'component_name strips characters that are invalid in an OpenAPI component key' do
        assert_equal 'FooBar', EntityBuilder.component_name('Foo Bar')
        assert_equal 'AggregateAggregate', EntityBuilder.component_name('Aggregate (Aggregate)')
        assert_equal 'a.b_c-d', EntityBuilder.component_name('a.b_c-d')
        assert_equal 'Bild', EntityBuilder.component_name(:Bild)
      end

      # --- structural invariants of a single schema ------------------------

      test 'call returns a valid OpenAPI 3.1 object schema' do
        template = DataCycleCore::ThingTemplate.first
        schema = EntityBuilder.new(template, locale: :en).call

        assert_equal 'object', schema['type']
        assert_equal template.template_name, schema['title']
        assert_equal ['@id', '@type'], schema['required']
        assert_kind_of Hash, schema['properties']
      end

      test 'every built schema exposes the shared envelope properties' do
        schema = EntityBuilder.new(DataCycleCore::ThingTemplate.first, locale: :en).call
        properties = schema['properties']

        # the identifier is exposed via @id, never as a separate `key` property
        EntityBuilder::ENVELOPE.each_key do |envelope_key|
          assert properties.key?(envelope_key), "expected envelope property #{envelope_key} to be present"
        end
        # @id is a bare UUID string (see _content_header.jb: json['@id'] = content.id)
        assert_equal({ 'type' => 'string', 'format' => 'uuid' }, properties['@id'])
      end

      # --- robustness across the whole instance schema ---------------------

      test 'the builder produces a valid schema for every ThingTemplate of the instance' do
        templates = DataCycleCore::ThingTemplate.all.to_a

        assert_operator templates.size, :>, 0, 'expected the dummy instance to define ThingTemplates'

        templates.each do |template|
          schema = EntityBuilder.new(template, locale: :en).call

          assert_equal 'object', schema['type'], "#{template.template_name}: wrong root type"
          assert_equal ['@id', '@type'], schema['required'], "#{template.template_name}: wrong required set"
          assert schema.dig('properties', '@id'), "#{template.template_name}: missing @id"
          assert schema.dig('properties', '@type'), "#{template.template_name}: missing @type"
        rescue StandardError => e
          flunk "EntityBuilder raised for template #{template.template_name}: #{e.class}: #{e.message}"
        end
      end

      # --- localization: the passed locale wins over the ambient one -------

      test 'the @type description is rendered in the requested locale, not the ambient one' do
        template = template_with_schema_types
        skip 'no template with schema.org types available' if template.nil?

        english = I18n.with_locale(:de) { EntityBuilder.new(template, locale: :en).call }
        german  = I18n.with_locale(:en) { EntityBuilder.new(template, locale: :de).call }

        en_desc = english.dig('properties', '@type', 'description')
        de_desc = german.dig('properties', '@type', 'description')

        assert_predicate en_desc, :present?, 'expected a localized @type description'
        assert_predicate de_desc, :present?, 'expected a localized @type description'
        assert_not_equal en_desc, de_desc, 'the @type description must differ between locales'
      end

      test 'building with an explicit locale never leaks a hardcoded language' do
        template = DataCycleCore::ThingTemplate.first

        I18n.available_locales.each do |locale|
          schema = EntityBuilder.new(template, locale:).call

          assert_equal 'object', schema['type'], "building in #{locale} failed"
        end
      end

      # _string_sd_license.jb is the one attribute partial that writes a sibling key:
      # it repeats sd_license as schema.org's `license` where the content is itself
      # the licensed work. #api_name_for only yields sdLicense, so without the alias
      # the component omitted a key v4 delivers (Bild, Audio, Video, Artikel, …).
      test 'a template that delivers sd_license as `license` documents both keys' do
        properties = sd_license_properties(template_name: 'Bild', ancestors: ['CreativeWork', 'MediaObject'])

        assert_includes properties, 'sdLicense', 'the property keeps its own api name'
        assert_includes properties, 'license', 'the partial also delivers it as license'
        assert_equal properties['sdLicense'], properties['license'], 'both keys describe the same value'
      end

      test 'a template outside the licensed-work set documents only sdLicense' do
        properties = sd_license_properties(template_name: 'Ladestation', ancestors: ['Place'])

        assert_includes properties, 'sdLicense'
        assert_not_includes properties, 'license', 'a Place is not itself the licensed work'
      end

      private

      # Component properties of a minimal in-memory template carrying sd_license.
      # Built here rather than picked from the instance because the alias depends on
      # the template name / schema.org ancestors, and no dummy template defines
      # sd_license at all — a data-driven version of this test would only skip.
      def sd_license_properties(template_name:, ancestors:)
        schema = {
          'name' => template_name,
          'content_type' => 'entity',
          'schema_ancestors' => ancestors,
          'properties' => {
            'sd_license' => {
              'label' => 'Lizenz-URL', 'type' => 'string', 'storage_location' => 'value', 'sorting' => 1,
              'api' => { 'disabled' => true, 'v4' => { 'disabled' => false, 'partial' => 'sd_license' } }
            }
          }
        }

        EntityBuilder.new(DataCycleCore::ThingTemplate.new(template_name:, schema:), locale: I18n.default_locale).call['properties']
      end

      # First template that exposes schema.org types, so its @type schema carries a
      # localized description (needed for the locale assertion above).
      def template_with_schema_types
        DataCycleCore::ThingTemplate.all.detect do |template|
          template.template_thing.api_schema_types.present?
        end
      end
    end
  end
end
