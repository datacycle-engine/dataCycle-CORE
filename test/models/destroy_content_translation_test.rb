# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class DestroyContentTranslationTest < ActiveSupport::TestCase
    def setup
      I18n.with_locale(:de) do
        @content = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Test Bild 1' })
      end
      I18n.with_locale(:en) do
        @content.set_data_hash(data_hash: { name: 'Test Image 1' }.deep_stringify_keys, partial_update: true)
      end
    end

    test 'delete a content' do
      assert_equal [:de, :en].to_set, @content.available_locales.to_set
      assert_equal 2, @content.searches.size
      assert_equal ['de', 'en'].to_set, @content.searches.pluck(:locale).to_set

      I18n.with_locale(:en) do
        @content.destroy_content(destroy_locale: true)
      end

      assert_equal [:de], @content.available_locales
      assert_equal 1, @content.searches.size
      assert_equal ['de'], @content.searches.pluck(:locale)
    end
  end
end
