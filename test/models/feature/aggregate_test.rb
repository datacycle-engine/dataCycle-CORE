# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class AggregateFeatureTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @aggregate_before_state = DataCycleCore.features[:aggregate].deep_dup
      DataCycleCore.features[:aggregate][:enabled] = true
      DataCycleCore::Feature::Aggregate.reload

      @content1 = create_content('Aggregate', { name: 'HEADLINE - NO TAGS 1' })
      @content2 = create_content('Aggregate', { name: 'HEADLINE - NO TAGS 2' })
      I18n.with_locale(:en) do
        @content2.set_data_hash(data_hash: { name: 'HEADLINE - NO TAGS 2 EN' })
      end
      @aggregate_content = create_content('Aggregate (Aggregate)', { aggregate_for: [@content1.id] })
    end

    after(:all) do
      DataCycleCore.features = DataCycleCore.features.except(:aggregate).merge({ aggregate: @aggregate_before_state })
      DataCycleCore::Feature::Aggregate.reload
    end

    test 'aggregate_content and contents get correct aggregate_type' do
      assert_equal 'aggregate', @aggregate_content.aggregate_type
      assert_equal 'belongs_to_aggregate', @content1.aggregate_type
      assert_equal 'default', @content2.aggregate_type
      assert_equal 'HEADLINE - NO TAGS 1', @aggregate_content.name
    end

    test 'aggregate_content and contents get correct aggregate_type after update' do
      @aggregate_content.set_data_hash(data_hash: { aggregate_for: [@content2.id] })

      assert_equal 'aggregate', @aggregate_content.aggregate_type
      assert_equal 'default', @content1.reload.aggregate_type
      assert_equal 'belongs_to_aggregate', @content2.reload.aggregate_type
      assert_equal 'HEADLINE - NO TAGS 2', @aggregate_content.name
    end

    test 'aggregate_content gets updated in all languages' do
      @aggregate_content.set_data_hash(data_hash: { aggregate_for: [@content2.id] })
      I18n.with_locale(:en) do
        @aggregate_content.set_data_hash(data_hash: { aggregate_for: [@content2.id] })
      end

      assert_equal [:de, :en], @aggregate_content.translated_locales
      assert_equal 'HEADLINE - NO TAGS 2', @aggregate_content.name
      assert_equal 'HEADLINE - NO TAGS 2 EN', I18n.with_locale(:en) { @aggregate_content.name }
    end

    test 'aggregate_content and contents get correct aggregate_type when deleted' do
      @aggregate_content.destroy
      assert_equal 'default', @content1.reload.aggregate_type
      assert_equal 'default', @content2.reload.aggregate_type
    end

    test 'aggregate_content gets update after content is changed' do
      assert_equal 'HEADLINE - NO TAGS 1', @aggregate_content.name

      @content1.set_data_hash(data_hash: { name: 'HEADLINE - NO TAGS 1 NEW' })

      assert_equal 'HEADLINE - NO TAGS 1 NEW', @aggregate_content.reload.name
    end
  end
end
