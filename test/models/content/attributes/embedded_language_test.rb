# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Content
    module Attributes
      class EmbeddedLanguageTest < ActiveSupport::TestCase
        def setup
          @data_set = DataCycleCore::TestPreparations.create_content(template_name: 'Embedded-Entity-Creative-Work-1', data_hash: DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'embedded').merge({
            'embedded_creative_work' => [DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'embedded')]
          }))
          returned_data_hash = @data_set.get_data_hash

          expected_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'embedded').merge({
            'embedded_creative_work' => [DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'embedded')]
          })
          assert_equal(0, @data_set.errors.messages.size)
          assert_equal(expected_hash.except('embedded_creative_work'), returned_data_hash.compact.except('embedded_creative_work', *DataCycleCore::TestPreparations.excepted_attributes))
          assert_equal(expected_hash['embedded_creative_work'].first, returned_data_hash['embedded_creative_work'].first.except('linked_place', *DataCycleCore::TestPreparations.excepted_attributes))

          # check consistency of data in DB
          assert_equal(1, DataCycleCore::Thing.where(template: false, template_name: 'Embedded-Creative-Work-2').count)
          assert_equal(1, DataCycleCore::Thing.where(template: false, template_name: 'Embedded-Entity-Creative-Work-1').count)
          assert_equal(1, DataCycleCore::ContentContent.count)
        end

        test 'insert embedded then delete embedded - one embedded in one language' do
          data_set = @data_set

          # delete embedded
          data_hash = data_set.get_data_hash
          data_hash['embedded_creative_work'] = []
          data_set.set_data_hash(data_hash: data_hash, prevent_history: true)
          data_set.save
          returned_data_hash = data_set.get_data_hash
          expected_hash = DataCycleCore::TestPreparations
            .load_dummy_data_hash('creative_works', 'embedded')
            .merge({ 'embedded_creative_work' => [] })

          assert_equal(0, data_set.errors.size)
          assert_equal(expected_hash, returned_data_hash.compact.except(*DataCycleCore::TestPreparations.excepted_attributes))

          # check consistency of data in DB
          assert_equal(1, DataCycleCore::Thing.where(template: false).count)
          assert_equal(0, DataCycleCore::ContentContent.count)
        end

        test 'delete object with emedded - one embedded in one language' do
          data_set = @data_set
          data_set.destroy_content(save_history: false)

          # check consistency of data in DB
          assert_equal(0, DataCycleCore::Thing.where(template: false, template_name: 'Embedded-Creative-Work-2').count)
          assert_equal(0, DataCycleCore::Thing.where(template: false, template_name: 'Embedded-Entity-Creative-Work-1').count)
          assert_equal(0, DataCycleCore::ContentContent.count)
        end

        test 'delete object with emedded (language specific) - one embedded in one language' do
          data_set = @data_set
          data_set.destroy_content(save_history: false, destroy_locale: true)

          # check consistency of data in DB
          assert_equal(0, DataCycleCore::Thing.where(template: false, template_name: 'Embedded-Creative-Work-2').count)
          assert_equal(0, DataCycleCore::Thing.where(template: false, template_name: 'Embedded-Entity-Creative-Work-1').count)
          assert_equal(0, DataCycleCore::ContentContent.count)
        end

        test 'do nothing for delete object with emedded (language specific in other language) - one embedded in one language' do
          data_set = @data_set
          I18n.with_locale(:en) { data_set.destroy_content(save_history: false, destroy_locale: true) }

          # check consistency of data in DB
          assert_equal(1, DataCycleCore::Thing.where(template: false, template_name: 'Embedded-Creative-Work-2').count)
          assert_equal(1, DataCycleCore::Thing.where(template: false, template_name: 'Embedded-Entity-Creative-Work-1').count)
          assert_equal(1, DataCycleCore::ContentContent.count)
        end
      end
    end
  end
end
