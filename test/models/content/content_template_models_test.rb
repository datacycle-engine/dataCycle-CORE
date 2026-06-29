# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'

module DataCycleCore
  module Content
    # [#45475] STI subclass casting (Content::Extensions::TemplateModels): each ThingTemplate becomes a
    # first-class STI subclass (e.g. DataCycleCore::Thing::Poi) with template_name as the inheritance
    # column, so rows round-trip to the right class and template-driven attributes (boost, content_type,
    # property names, data_type, schema_types) follow the template. becomes! is the pure in-memory cast
    # primitive (returns a NEW, unsaved instance; runs no feasibility/domain checks).
    #
    # The import-driven in-place type CONVERSION built on top of this (can_become?/update_template!/
    # obsolete cleanup, in Content::Extensions::TemplateConversion) is covered by content_template_conversion_test.rb.
    class ContentTemplateModelsTest < DataCycleCore::TestCases::ActiveSupportTestCase
      before(:all) do
        @organization_dt = DataCycleCore::Concept.for_tree('Inhaltstypen').with_internal_name('Organisation').pluck(:classification_id)
        @organization_st = DataCycleCore::Concept.for_tree('SchemaTypes').with_internal_name('Organization').pluck(:classification_id)

        @content = DataCycleCore::TestPreparations.create_content(template_name: 'Organization', data_hash: { name: 'test name de' })

        assert_equal @organization_dt, @content.data_type.pluck(:id)
        assert_equal @organization_st, @content.schema_types.pluck(:id)
        assert_in_delta(1.0, @content.boost)
        assert_equal 'entity', @content.content_type
      end

      # re-fetch via Thing.find (not reload): the original reference is still the old STI subclass after the change
      test 'update(template_name:) converts the Thing in place; re-fetched it loads as the new STI subclass with boost, content_type, property names, data_type and schema_types refreshed to the target template (Artikel)' do
        tt = DataCycleCore::ThingTemplate.find_by(template_name: 'Artikel').template_thing
        dt = DataCycleCore::Concept.for_tree('Inhaltstypen').with_internal_name('Artikel').pluck(:classification_id)
        st = DataCycleCore::Concept.for_tree('SchemaTypes').with_internal_name('dcls:Artikel').pluck(:classification_id)

        @content.update(template_name: 'Artikel')
        new_content = DataCycleCore::Thing.find(@content.id)

        assert_in_delta(100.0, new_content.boost)
        assert_equal 'entity', new_content.content_type
        assert_equal tt.translatable_property_names, new_content.translatable_property_names
        assert_equal tt.untranslatable_property_names, new_content.untranslatable_property_names
        assert_equal dt, new_content.data_type.pluck(:id)
        assert_equal st, new_content.schema_types.pluck(:id)
      end

      test 'becomes!(name) returns an in-memory copy cast to the target STI subclass, refreshing content_type and property names, without saving (embedded Action)' do
        tt = DataCycleCore::ThingTemplate.find_by(template_name: 'Action').template_thing
        new_content = @content.becomes!('Action')

        assert_in_delta(1.0, new_content.boost)
        assert_equal 'embedded', new_content.content_type
        assert_equal tt.translatable_property_names, new_content.translatable_property_names
        assert_equal tt.untranslatable_property_names, new_content.untranslatable_property_names
      end

      test 'assigning thing_template= (a ThingTemplate) refreshes boost, content_type and property names in memory; save! then persists the new data_type and schema_types (Artikel)' do
        tt = DataCycleCore::ThingTemplate.find_by(template_name: 'Artikel')
        @content.thing_template = tt
        dt = DataCycleCore::Concept.for_tree('Inhaltstypen').with_internal_name('Artikel').pluck(:classification_id)
        st = DataCycleCore::Concept.for_tree('SchemaTypes').with_internal_name('dcls:Artikel').pluck(:classification_id)

        assert_in_delta(100.0, @content.boost)
        assert_equal 'entity', @content.content_type
        assert_equal tt.template_thing.translatable_property_names, @content.translatable_property_names
        assert_equal tt.template_thing.untranslatable_property_names, @content.untranslatable_property_names

        @content.save!

        assert_equal dt, @content.data_type.pluck(:id)
        assert_equal st, @content.schema_types.pluck(:id)
      end

      # re-fetch via Thing.find to load the new STI class
      test 'update(thing_template:) with a ThingTemplate object converts and persists; re-fetched it carries the new boost, content_type, property names, data_type and schema_types (Artikel)' do
        tt = DataCycleCore::ThingTemplate.find_by(template_name: 'Artikel')
        dt = DataCycleCore::Concept.for_tree('Inhaltstypen').with_internal_name('Artikel').pluck(:classification_id)
        st = DataCycleCore::Concept.for_tree('SchemaTypes').with_internal_name('dcls:Artikel').pluck(:classification_id)

        @content.update(thing_template: tt)
        new_content = DataCycleCore::Thing.find(@content.id) # reload with new STI class

        assert_in_delta(100.0, new_content.boost)
        assert_equal 'entity', new_content.content_type
        assert_equal tt.template_thing.translatable_property_names, new_content.translatable_property_names
        assert_equal tt.template_thing.untranslatable_property_names, new_content.untranslatable_property_names
        assert_equal dt, new_content.data_type.pluck(:id)
        assert_equal st, new_content.schema_types.pluck(:id)
      end

      test 'becomes!(name) returns an unsaved in-memory cast (boost, content_type and property names already refreshed); a subsequent save! by the caller persists the new data_type and schema_types (Artikel)' do
        tt = DataCycleCore::ThingTemplate.find_by(template_name: 'Artikel').template_thing
        new_content = @content.becomes!('Artikel')
        dt = DataCycleCore::Concept.for_tree('Inhaltstypen').with_internal_name('Artikel').pluck(:classification_id)
        st = DataCycleCore::Concept.for_tree('SchemaTypes').with_internal_name('dcls:Artikel').pluck(:classification_id)

        assert_in_delta(100.0, new_content.boost)
        assert_equal 'entity', new_content.content_type
        assert_equal tt.translatable_property_names, new_content.translatable_property_names
        assert_equal tt.untranslatable_property_names, new_content.untranslatable_property_names

        new_content.save!

        assert_equal dt, new_content.data_type.pluck(:id)
        assert_equal st, new_content.schema_types.pluck(:id)
      end

      # reload (not re-fetch) works here because becomes! already set the new STI class on this very object
      test 'a becomes!-cast object can be saved and then reloaded in place without ActiveRecord::SubclassNotFound, with all template attributes refreshed (Artikel)' do
        tt = DataCycleCore::ThingTemplate.find_by(template_name: 'Artikel').template_thing
        dt = DataCycleCore::Concept.for_tree('Inhaltstypen').with_internal_name('Artikel').pluck(:classification_id)
        st = DataCycleCore::Concept.for_tree('SchemaTypes').with_internal_name('dcls:Artikel').pluck(:classification_id)

        new_content = @content.becomes!('Artikel')
        new_content.save!
        new_content.reload

        assert_in_delta(100.0, new_content.boost)
        assert_equal 'entity', new_content.content_type
        assert_equal tt.translatable_property_names, new_content.translatable_property_names
        assert_equal tt.untranslatable_property_names, new_content.untranslatable_property_names
        assert_equal dt, new_content.data_type.pluck(:id)
        assert_equal st, new_content.schema_types.pluck(:id)
      end

      # one-shot / synthetic templates (e.g. the bulk-edit "Generic" aggregate)
      # have no persisted ThingTemplate, so no STI subclass is generated. They
      # must resolve to the base class instead of AR's compute_type resolving an
      # unrelated constant (the DataCycleCore::Generic importer module), which it
      # would otherwise reject with SubclassNotFound.
      test 'sti_class_for resolves a synthetic "Generic" template (no persisted ThingTemplate) to the base class for both Thing and Thing::History, avoiding SubclassNotFound' do
        assert_equal DataCycleCore::Thing, DataCycleCore::Thing.sti_class_for('Generic')
        assert_equal DataCycleCore::Thing::History, DataCycleCore::Thing::History.sti_class_for('Generic')
      end

      test 'a Thing built from an in-memory (unpersisted) "Generic" ThingTemplate instantiates as the base Thing and is generic_template?' do
        generic = DataCycleCore::Thing.new(
          id: SecureRandom.uuid,
          thing_template: DataCycleCore::ThingTemplate.new(
            template_name: 'Generic',
            schema: { name: 'Generic', type: 'object', schema_type: 'Generic', content_type: 'entity', features: {}, properties: {} }.deep_stringify_keys!
          )
        )

        assert_instance_of DataCycleCore::Thing, generic
        assert_predicate generic, :generic_template?
      end

      # counterpart to the synthetic "Generic" case: real templates must still resolve to their generated subclass
      test 'sti_class_for resolves a real template name ("Artikel") to its generated STI subclass DataCycleCore::Thing::Artikel (< Thing)' do
        artikel_class = DataCycleCore::Thing.sti_class_for('Artikel')

        assert_equal 'DataCycleCore::Thing::Artikel', artikel_class.name
        assert_operator artikel_class, :<, DataCycleCore::Thing
      end
    end
  end
end
