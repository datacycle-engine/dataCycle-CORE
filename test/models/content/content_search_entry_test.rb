# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'

module DataCycleCore
  module Content
    class ContentSearchEntryTest < DataCycleCore::TestCases::ActiveSupportTestCase
      before(:all) do
        @name_de = 'test name de'
        @name_en = 'test name de'
        I18n.with_locale(:en) do
          @organization = DataCycleCore::TestPreparations.create_content(template_name: 'Organization', data_hash: { name: @name_en })
        end
      end

      test 'test search entry de is created' do
        assert_equal 1, @organization.searches.size
        assert_equal ['en'], @organization.searches.pluck(:locale)
      end

      test 'test search entry de is created after set_data_hash with update_search_all false' do
        @organization.set_data_hash(data_hash: { name: @name_de }, partial_update: true, update_search_all: false)

        assert_equal 2, @organization.searches.size
        assert_empty ['de', 'en'].difference(@organization.searches.pluck(:locale))
      end

      test 'test search entry de is created after set_data_hash with update_search_all true' do
        @organization.set_data_hash(data_hash: { name: @name_de }, partial_update: true)

        assert_equal 2, @organization.searches.size
        assert_empty ['de', 'en'].difference(@organization.searches.pluck(:locale))
      end

      test 'test search entry de is not created after calling search_languages in non-existing locale' do
        @organization.search_languages(true)

        assert_equal 1, @organization.searches.size
        assert_equal ['en'], @organization.searches.pluck(:locale)
      end
    end
  end
end
