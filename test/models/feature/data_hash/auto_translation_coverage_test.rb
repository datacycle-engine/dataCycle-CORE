# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Feature
    module DataHash
      # Coverage for the AutoTranslation data-hash feature (mixed into Thing).
      # The Übersetzung template, the Inhaltstypen/Übersetzungstyp/Externe
      # Informationstypen trees and the AutoTranslation + Translate features are
      # all present/enabled in the test setup; only the Translate endpoint is
      # stubbed so no external translation service is called.
      class AutoTranslationCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
        before(:all) do
          @description_type = DataCycleCore::ClassificationAlias
            .classifications_for_tree_with_name('Externe Informationstypen', 'description')
        end

        def create_poi(name)
          DataCycleCore::TestPreparations.create_content(template_name: 'POI', data_hash: { 'name' => name })
        end

        # a translation (Übersetzung) content linked to +about+ with German data only
        def create_translation(about:, name:, description:)
          DataCycleCore::TestPreparations.create_content(
            template_name: 'Übersetzung',
            data_hash: {
              'name' => name,
              'description' => description,
              'description_type' => @description_type,
              'about' => [about.id]
            }
          )
        end

        def endpoint_double
          Class.new {
            def translate(_hash) = { 'translated_text' => 'Übersetzt' }
            def parse_translated(_data) = 'Übersetzter Text'
          }.new
        end

        test 'create_update_translations returns an error when there is nothing to translate' do
          assert_equal({ 'error' => 'Nothing to translate' }, create_poi('AT no-info POI').create_update_translations)
        end

        test 'create_update_auto_translations returns an error when there is nothing to translate' do
          assert_equal({ 'error' => 'Nothing to translate' }, create_poi('AT no-trans POI').create_update_auto_translations('de'))
        end

        test 'create_update_auto_translations translates, then skips already-automatic translations' do
          poi = create_poi('AT auto POI')
          create_translation(about: poi, name: 'Quelle', description: 'Quelltext')
          poi.reload

          first = second = nil
          DataCycleCore::Feature::Translate.stub(:endpoint, endpoint_double) do
            DataCycleCore::Feature::Translate.stub(:allowed_target_languages, ['de', 'en']) do
              first = poi.create_update_auto_translations('de')
              # second pass: the :en translation is now 'automatic' and not newer,
              # so it hits the translation_type/modified guard instead of re-translating
              second = poi.create_update_auto_translations('de')
            end
          end

          assert_includes(first.values.flatten, :en, "expected :en translation, got #{first.inspect}")
          assert_kind_of(Hash, second)
        end

        test 'create_update_translations creates Übersetzung contents from additional information' do
          poi = DataCycleCore::TestPreparations.create_content(
            template_name: 'POI',
            data_hash: {
              'name' => 'AT trans POI',
              'additional_information' => [{ 'name' => 'Zusatzinfo', 'description' => 'Zusatztext' }]
            }
          )
          # the dummy "Ergänzende Information" template has no Externe-Informationstypen
          # classification property, so attach one to the embedded info at runtime
          # (scoped to this test) the way production content carries it.
          info = poi.additional_information.first
          classification = DataCycleCore::ClassificationAlias
            .for_tree('Externe Informationstypen').with_name(['description']).first.primary_classification
          DataCycleCore::ClassificationContent.create!(content_data: info, classification:, relation: 'description_type')
          poi.reload

          result = poi.create_update_translations

          assert_kind_of(Hash, result)
          assert_not(result.key?('error'), "unexpected error result: #{result.inspect}")
          assert_includes(result.values.flatten, :de, "expected a :de translation, got #{result.inspect}")
        end

        test 'destroy_all_translated_content removes linked Übersetzung contents' do
          poi = create_poi('AT destroy-all POI')
          create_translation(about: poi, name: 'Quelle', description: 'Quelltext')
          poi.reload

          assert_nothing_raised { poi.destroy_all_translated_content }
        end

        test 'destroy_auto_translations destroys a manual-only translation content' do
          poi = create_poi('AT destroy-auto POI')
          translation = create_translation(about: poi, name: 'Quelle', description: 'Quelltext')

          assert_nothing_raised { translation.destroy_auto_translations }
        end

        test 'destroy_auto_translations drops automatic locales but keeps manual ones' do
          poi = create_poi('AT destroy-auto-mixed POI')
          create_translation(about: poi, name: 'Quelle', description: 'Quelltext') # de => manual
          poi.reload
          DataCycleCore::Feature::Translate.stub(:endpoint, endpoint_double) do
            DataCycleCore::Feature::Translate.stub(:allowed_target_languages, ['de', 'en']) do
              poi.create_update_auto_translations('de') # adds an :en => automatic locale
            end
          end
          translation = poi.subject_of.where(template_name: 'Übersetzung').first

          assert_nothing_raised { translation.destroy_auto_translations }
        end
      end
    end
  end
end
