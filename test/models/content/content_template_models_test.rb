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

        perform_enqueued_jobs { @content.update(template_name: 'Artikel') }
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

        perform_enqueued_jobs { @content.save! }

        assert_equal dt, @content.data_type.pluck(:id)
        assert_equal st, @content.schema_types.pluck(:id)
      end

      # re-fetch via Thing.find to load the new STI class
      test 'update(thing_template:) with a ThingTemplate object converts and persists; re-fetched it carries the new boost, content_type, property names, data_type and schema_types (Artikel)' do
        tt = DataCycleCore::ThingTemplate.find_by(template_name: 'Artikel')
        dt = DataCycleCore::Concept.for_tree('Inhaltstypen').with_internal_name('Artikel').pluck(:classification_id)
        st = DataCycleCore::Concept.for_tree('SchemaTypes').with_internal_name('dcls:Artikel').pluck(:classification_id)

        perform_enqueued_jobs { @content.update(thing_template: tt) }
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

        perform_enqueued_jobs { new_content.save! }

        assert_equal dt, new_content.data_type.pluck(:id)
        assert_equal st, new_content.schema_types.pluck(:id)
      end

      # reload (not re-fetch) works here because becomes! already set the new STI class on this very object
      test 'a becomes!-cast object can be saved and then reloaded in place without ActiveRecord::SubclassNotFound, with all template attributes refreshed (Artikel)' do
        tt = DataCycleCore::ThingTemplate.find_by(template_name: 'Artikel').template_thing
        dt = DataCycleCore::Concept.for_tree('Inhaltstypen').with_internal_name('Artikel').pluck(:classification_id)
        st = DataCycleCore::Concept.for_tree('SchemaTypes').with_internal_name('dcls:Artikel').pluck(:classification_id)

        new_content = @content.becomes!('Artikel')
        perform_enqueued_jobs { new_content.save! }
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

      # Regression: the STI subclass name must NOT depend on the active locale. sti_subclass_name_for
      # transliterates via I18n (locale-sensitive), so "Übersetzung" becomes "Uebersetzung" under
      # :de/:en (they define an ü->ue rule) but "Ubersetzung" under a locale without that rule (e.g. :it).
      # sti_class_for both GENERATES and RESOLVES the constant and runs on every record instantiation
      # (find_sti_class) — frequently inside I18n.with_locale(target_locale) blocks (auto-translation).
      # A locale-dependent name generated "Uebersetzung" but looked up "Ubersetzung", so resolution fell
      # back to the base class and AR raised SubclassNotFound ("Thing is not a subclass of ...Uebersetzung").
      test 'sti_class_for resolves an umlaut template name ("Übersetzung") to the same STI subclass under any active locale' do
        # precondition: this name really does transliterate differently per locale, otherwise the
        # assertions below would silently be a no-op (pick another locale here if :it ever gets a rule)
        assert_not_equal(
          I18n.transliterate('Übersetzung', locale: :de),
          I18n.transliterate('Übersetzung', locale: :it),
          'expected "Übersetzung" to transliterate differently under :de vs :it'
        )

        uebersetzung = DataCycleCore::Thing.sti_class_for('Übersetzung')

        assert_equal 'DataCycleCore::Thing::Uebersetzung', uebersetzung.name
        assert_operator uebersetzung, :<, DataCycleCore::Thing

        # under a locale whose transliteration drops the umlaut, resolution must still return the same
        # subclass — both from the base class and from the subclass itself (find_sti_class is invoked on
        # the subclass when a translation content is reloaded during auto-translation)
        I18n.with_locale(:it) do
          assert_equal uebersetzung, DataCycleCore::Thing.sti_class_for('Übersetzung')
          assert_equal uebersetzung, DataCycleCore::Thing::Uebersetzung.sti_class_for('Übersetzung')
        end
      end

      # Regression: the bulk init runs once per process and publishes its flag before its first
      # const_set, so a template it had not reached yet was reported as a missing constant to every
      # other thread — the editor fires one remote_render per embedded viewer into exactly that window.
      # find_sti_class recovered by template name, but a constant reference (ParamsResolver
      # deserializing a remote_render {class:, id:} pair) constantized to nil, and the caller silently
      # received the raw params hash — "undefined method 'schema' for ... HashWithIndifferentAccess".
      #
      # The names the init records cover this without re-reading the templates, which is all a
      # production process can need: it imports them before it restarts.
      test 'a template constant this process has not generated yet is created from the names the init recorded' do
        DataCycleCore::Thing.ensure_sti_subclasses_initialized_once!
        DataCycleCore::Thing.send(:remove_const, :Artikel)

        artikel_class = DataCycleCore::ThingTemplate.stub(:pluck, ->(*) { raise 'templates re-read' }) do
          'DataCycleCore::Thing::Artikel'.safe_constantize
        end

        assert_equal 'DataCycleCore::Thing::Artikel', artikel_class&.name
        assert_equal artikel_class, DataCycleCore::Thing.sti_class_for('Artikel')
      end

      # development and test only: rails dc:update and the test setup import templates into a process
      # that has already initialized, and no reload or after_commit tells it about them
      test 'a template imported after the init is found by looking the names up again' do
        DataCycleCore::Thing.ensure_sti_subclasses_initialized_once!
        recorded = DataCycleCore::Thing.instance_variable_get(:@sti_template_names)
        DataCycleCore::Thing.instance_variable_set(:@sti_template_names, recorded - ['Artikel'])
        DataCycleCore::Thing.send(:remove_const, :Artikel)

        assert_equal 'DataCycleCore::Thing::Artikel', 'DataCycleCore::Thing::Artikel'.safe_constantize&.name
      ensure
        DataCycleCore::Thing.instance_variable_set(:@sti_template_names, recorded)
      end

      test 'a constant matching no template is still reported as missing' do
        assert_nil 'DataCycleCore::Thing::NoSuchTemplate'.safe_constantize
        assert_raises(NameError) { DataCycleCore::Thing.const_get(:NoSuchTemplate, false) }
      end
    end
  end
end
