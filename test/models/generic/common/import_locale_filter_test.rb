# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # [#48137] Language-neutral (untranslatable) properties are only imported from the primary
  # locale (I18n.default_locale), so a secondary locale pass that does not carry them cannot
  # delete them again (#49571: "Wandern" imported for de, missing for en, en wins).
  class ImportLocaleFilterTest < DataCycleCore::TestCases::ActiveSupportTestCase
    include DataCycleCore::Generic::Common::ImportFunctionsDataHelper

    # the end-to-end run needs a real transformation to hand to ImportContents
    module Transformations
      def self.identity(_external_source_id = nil)
        ->(data) { data }
      end
    end

    before(:all) do
      @external_system = DataCycleCore::ExternalSystem.find_by(identifier: 'local-system')
      @other_system = DataCycleCore::ExternalSystem.find_by(identifier: 'remote-system')
      @template = DataCycleCore::ThingTemplate.find_by(template_name: 'POI')
      @conversion_source = DataCycleCore::ThingTemplate.find_by(template_name: 'TemplateConversionSource')
      @conversion_target = DataCycleCore::ThingTemplate.find_by(template_name: 'TemplateConversionTarget')
      @utility_object = DataCycleCore::Generic::ImportObject.new(
        external_source: @external_system,
        import: {
          import_strategy: 'DataCycleCore::Generic::Common::ImportContents',
          source_type: 'contents'
        }
      )
      @target_a = DataCycleCore::TestPreparations.create_content(template_name: 'POI', data_hash: { name: 'Link Target A' })
      @target_b = DataCycleCore::TestPreparations.create_content(template_name: 'POI', data_hash: { name: 'Link Target B' })
    end

    # the source knows the classification in de but not in en, so the transformation emits an
    # empty list for en - which used to clear what the de pass had just set
    test 'a secondary locale does not delete a classification the primary locale imported' do
      category_ids = get_classification_ids('POI - Kategorien', ['Restaurant'])

      content = import(:de, { 'external_key' => 'lf-keep', 'name' => 'Restaurant DE', 'poi_category' => category_ids })

      assert_equal category_ids, classification_ids(content, 'poi_category'), 'guard: the primary locale sets the classification'

      import(:en, { 'external_key' => 'lf-keep', 'name' => 'Restaurant EN', 'poi_category' => [] })

      assert_equal category_ids, classification_ids(content, 'poi_category')
    end

    test 'a secondary locale does not overwrite a classification with its own value' do
      de_ids = get_classification_ids('Tags', ['Tag 1'])
      en_ids = get_classification_ids('Tags', ['Tag 2'])

      content = import(:de, { 'external_key' => 'lf-overwrite', 'name' => 'Tagged DE', 'tags' => de_ids })

      assert_equal de_ids, classification_ids(content, 'tags')

      import(:en, { 'external_key' => 'lf-overwrite', 'name' => 'Tagged EN', 'tags' => en_ids })

      assert_equal de_ids, classification_ids(content, 'tags')
    end

    # the same shape as the two classification cases above, for the other relation type: a link
    # lives in content_contents, which has no locale, and #set_linked deletes unconditionally -
    # unlike a classification there is no 'not_translated' escape to fall back on
    test 'a secondary locale does not delete a linked relation the primary locale imported' do
      content = import(:de, { 'external_key' => 'lf-link-keep', 'name' => 'Linking DE', 'linked_thing' => [@target_a.id] })

      assert_equal [@target_a.id], linked_ids(content, 'linked_thing'), 'guard: the primary locale sets the link'

      import(:en, { 'external_key' => 'lf-link-keep', 'name' => 'Linking EN', 'linked_thing' => [] })

      assert_equal [@target_a.id], linked_ids(content, 'linked_thing')
    end

    test 'a secondary locale does not overwrite a linked relation with its own target' do
      content = import(:de, { 'external_key' => 'lf-link-overwrite', 'name' => 'Linking DE', 'linked_thing' => [@target_a.id] })

      assert_equal [@target_a.id], linked_ids(content, 'linked_thing')

      import(:en, { 'external_key' => 'lf-link-overwrite', 'name' => 'Linking EN', 'linked_thing' => [@target_b.id] })

      assert_equal [@target_a.id], linked_ids(content, 'linked_thing')
    end

    test 'the primary locale still writes linked relations' do
      content = import(:de, { 'external_key' => 'lf-link-primary', 'name' => 'Linking DE', 'linked_thing' => [@target_a.id] })

      import(:de, { 'external_key' => 'lf-link-primary', 'name' => 'Linking DE', 'linked_thing' => [@target_b.id] })

      assert_equal [@target_b.id], linked_ids(content, 'linked_thing')

      import(:de, { 'external_key' => 'lf-link-primary', 'name' => 'Linking DE', 'linked_thing' => [] })

      assert_empty linked_ids(content, 'linked_thing'), 'the primary locale must still be able to clear them'
    end

    test 'content without a primary locale translation keeps taking linked relations from the secondary locale' do
      content = import(:en, { 'external_key' => 'lf-link-en-only', 'name' => 'Linking EN', 'linked_thing' => [@target_a.id] })

      assert_equal [:en], content.reload.translated_locales, 'guard: there is no primary locale to take the link from'

      import(:en, { 'external_key' => 'lf-link-en-only', 'name' => 'Linking EN', 'linked_thing' => [@target_b.id] })

      assert_equal [@target_b.id], linked_ids(content, 'linked_thing')
    end

    test 'a secondary locale still writes translatable properties' do
      content = import(:de, { 'external_key' => 'lf-translatable', 'name' => 'Name DE', 'price_range' => 'ab 10 Euro' })
      import(:en, { 'external_key' => 'lf-translatable', 'name' => 'Name EN', 'price_range' => 'from 10 Euro' })
      content.reload

      I18n.with_locale(:de) do
        assert_equal 'Name DE', content.name
        assert_equal 'ab 10 Euro', content.price_range
      end

      I18n.with_locale(:en) do
        assert_equal 'Name EN', content.name
        assert_equal 'from 10 Euro', content.price_range
      end

      import(:en, { 'external_key' => 'lf-translatable', 'name' => 'Name EN', 'price_range' => nil })
      content.reload

      I18n.with_locale(:en) { assert_nil content.price_range, 'a secondary locale must still be able to clear them' }
      I18n.with_locale(:de) { assert_equal 'ab 10 Euro', content.price_range }
    end

    test 'the primary locale still writes untranslatable properties' do
      first_ids = get_classification_ids('Tags', ['Tag 1'])
      second_ids = get_classification_ids('Tags', ['Tag 2'])

      content = import(:de, { 'external_key' => 'lf-primary-writes', 'name' => 'Primary', 'tags' => first_ids })

      assert_equal first_ids, classification_ids(content, 'tags')

      import(:de, { 'external_key' => 'lf-primary-writes', 'name' => 'Primary', 'tags' => second_ids })

      assert_equal second_ids, classification_ids(content, 'tags')

      import(:de, { 'external_key' => 'lf-primary-writes', 'name' => 'Primary', 'tags' => [] })

      assert_empty classification_ids(content, 'tags'), 'the primary locale must still be able to clear them'
    end

    test 'content created in a secondary locale gets its untranslatable properties' do
      category_ids = get_classification_ids('POI - Kategorien', ['Restaurant'])

      content = import(:en, { 'external_key' => 'lf-new-in-en', 'name' => 'Only EN', 'poi_category' => category_ids })

      assert_equal category_ids, classification_ids(content, 'poi_category')
    end

    test 'content without a primary locale translation keeps taking untranslatable properties from the secondary locale' do
      first_ids = get_classification_ids('Tags', ['Tag 1'])
      second_ids = get_classification_ids('Tags', ['Tag 2'])

      content = import(:en, { 'external_key' => 'lf-en-only', 'name' => 'EN only', 'tags' => first_ids })

      assert_equal [:en], content.reload.translated_locales, 'guard: there is no primary locale to take the data from'

      import(:en, { 'external_key' => 'lf-en-only', 'name' => 'EN only', 'tags' => second_ids })

      assert_equal second_ids, classification_ids(content, 'tags')
    end

    # potential_action is 'translated: true', so the relation is untranslatable while the embedded
    # Action itself is translated - and only this pass can give it its secondary locale text
    test 'an embedded property stays importable in a secondary locale' do
      content = import(:de, { 'external_key' => 'lf-embedded', 'name' => 'Embedded DE', 'potential_action' => [{ 'name' => 'Karte' }] })
      action = content.reload.potential_action.first

      assert_equal 'Karte', action.name, 'guard: the primary locale creates the embedded child'

      import(:en, { 'external_key' => 'lf-embedded', 'name' => 'Embedded EN', 'potential_action' => [{ 'id' => action.id, 'name' => 'Map' }] })

      assert_equal ['Karte', 'Map'], [translated(action, :de, :name), translated(action, :en, :name)]
    end

    test 'the imported flags of untranslatable properties are left alone in a secondary locale' do
      content = create_content('POI', { name: 'Imported Flags', external_key: 'lf-flags', external_source_id: @external_system.id })

      assert_equal ['data_pool'], content.properties_with_imported_flag, 'guard: there is a flagged property to leave alone'
      assert_equal [:de], content.translated_locales, 'guard: the content has the primary locale'

      assert_includes captured_data_hash(content, :de).keys, 'data_pool_imported'
      assert_not_includes captured_data_hash(content, :en).keys, 'data_pool_imported'
    end

    test 'import_untranslatable? is false only for a secondary locale on content that has the primary one' do
      content = import(:de, { 'external_key' => 'lf-predicate', 'name' => 'Predicate' }).reload

      I18n.with_locale(:de) { assert import_untranslatable?(content) }
      I18n.with_locale(:en) { assert_not import_untranslatable?(content) }
    end

    test 'a pending primary system change keeps untranslatable properties importable in a secondary locale' do
      content = import(:de, { 'external_key' => 'lf-primary-change', 'name' => 'Primary Change' }).reload

      I18n.with_locale(:en) do
        assert_not import_untranslatable?(content), 'guard: without a pending change it would be filtered'

        content.external_source_id = @other_system.id

        assert import_untranslatable?(content), 'the nil resets of change_primary_system! must reach set_data_hash'
      end
    end

    test 'keep_translatable_only! keeps translatable and internal keys and drops the rest' do
      data = {
        'name' => 'Name', 'price_range' => 'ab 10 Euro', 'external_key' => 'lf-slice',
        'external_system_data' => [{ 'name' => 'other' }], 'id' => 'some-id',
        'poi_category' => ['x'], 'linked_thing' => ['y'], 'dc_mongo_key' => 'z'
      }

      keep_translatable_only!(data, @template.template_thing)

      # 'id' is not in the keep list: create_or_update_content strips it before calling this
      assert_equal ['external_key', 'external_system_data', 'name', 'price_range'], data.keys.sort
    end

    # a template conversion concerns every locale at once and #obsolete_property_names_for drops the
    # untranslatable data of everything that is not global/local, so it belongs to the primary locale
    # pass - the only one whose write can map it onto the new template again
    test 'a secondary locale leaves the template conversion to the primary locale' do
      content = import(:de, { 'external_key' => 'lf-convert', 'name' => 'Source DE', 'mandatory_note' => 'must be set', 'removable_note' => 'de note' }, template: @conversion_source)

      assert_equal 'TemplateConversionSource', content.template_name, 'guard: the content starts out on the source template'

      # the config now maps the item to the target template, whose transformation no longer emits
      # the source's own properties
      import(:en, { 'external_key' => 'lf-convert', 'name' => 'Source EN' }, template: @conversion_target)
      # not #reload: a conversion leaves the instance stale (STI), which would raise instead of fail
      unconverted = DataCycleCore::Thing.find(content.id)

      assert_equal 'TemplateConversionSource', unconverted.template_name
      assert_equal 'de note', unconverted.removable_note, 'the obsolete property is not dropped by a pass that cannot refill it'
      assert_equal 'Source EN', translated(unconverted, :en, :name), 'guard: the secondary pass still writes its translation'

      converted = import(:de, { 'external_key' => 'lf-convert', 'name' => 'Source DE' }, template: @conversion_target)

      assert_equal 'TemplateConversionTarget', converted.template_name
    end

    # the same shape as the headline test, but through the layer #49571 actually surfaces in:
    # process_step slices to the template's importable properties and short-circuits per locale
    # on the stored transformation hash
    test 'an end to end ImportContents run over de and en keeps the classification only de delivers' do
      category_ids = get_classification_ids('POI - Kategorien', ['Restaurant'])
      de_data = { 'external_key' => 'lf-e2e', 'name' => 'Restaurant DE', 'poi_category' => category_ids }

      import_contents(:de, de_data)
      content = import_contents(:en, { 'external_key' => 'lf-e2e', 'name' => 'Restaurant EN', 'poi_category' => [] })

      assert_equal category_ids, classification_ids(content, 'poi_category')

      # the next run of the same source: the de payload has not changed, so that pass is skipped on
      # its stored hash and the changed en pass is the only one that writes
      assert_equal 0, create_or_update_calls { import_contents(:de, de_data) }, 'guard: an unchanged de pass never reaches create_or_update_content'

      content = import_contents(:en, { 'external_key' => 'lf-e2e', 'name' => 'Restaurant EN 2', 'poi_category' => [] })

      assert_equal 'Restaurant EN 2', translated(content, :en, :name), 'guard: the en pass did run'
      assert_equal category_ids, classification_ids(content, 'poi_category')
    end

    private

    def import(locale, data, template: @template)
      I18n.with_locale(locale) do
        create_or_update_content(utility_object: @utility_object, template:, data:)
      end
    end

    def import_contents(locale, raw_data)
      DataCycleCore::Generic::Common::ImportContents.process_content(
        utility_object: @utility_object,
        raw_data:,
        locale:,
        options: {
          transformations: Transformations.name,
          import: { main_content: { template: 'POI', transformation: 'identity' } }
        }
      )
    end

    def create_or_update_calls(&)
      calls = 0

      counting = lambda do |**|
        calls += 1
        nil
      end

      DataCycleCore::Generic::Common::ImportFunctions.stub(:create_or_update_content, counting, &)

      calls
    end

    def classification_ids(content, relation)
      content.reload.classification_contents.where(relation:).pluck(:classification_id)
    end

    def linked_ids(content, relation)
      content.reload.content_content_a.where(relation_a: relation).pluck(:content_b_id)
    end

    def translated(content, locale, key)
      I18n.with_locale(locale) { content.reload.public_send(key) }
    end

    # the data hash create_or_update_content hands to set_data_hash for +locale+
    def captured_data_hash(content, locale)
      captured = nil
      capture_set_data_hash = lambda do |**kwargs|
        captured = kwargs[:data_hash]
        true
      end

      content.stub(:set_data_hash, capture_set_data_hash) do
        stub(:find_or_initialize_content, ->(**) { content }) do
          import(locale, { 'external_key' => content.external_key, 'name' => "Captured #{locale}" })
        end
      end

      captured
    end
  end
end
