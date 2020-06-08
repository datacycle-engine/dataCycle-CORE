# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class I18nFallback < ActiveSupport::TestCase
    test 'make sure config.i18n.fallback is set to false' do
      template = DataCycleCore::Thing.find_by(template: true, template_name: 'TestSimple')
      validation = template.schema
      data_set = DataCycleCore::Thing.new
      data_set.schema = validation
      data_set.save

      data_hash_de = { 'name' => 'Dies ist ein Test!' }
      data_hash_en = { 'name' => 'This is a Test!' }

      data_set.set_data_hash(data_hash: data_hash_de)
      data_set.save
      assert_equal(data_hash_de, data_set.get_data_hash.except('id'))

      I18n.with_locale(:en) do
        data_set.set_data_hash(data_hash: data_hash_en)
        data_set.save
        assert_equal(data_hash_en, data_set.get_data_hash.except('id'))
      end

      assert_equal(data_hash_de, data_set.get_data_hash.except('id'))
      assert_equal(data_hash_en, I18n.with_locale(:en) { data_set.get_data_hash.except('id') })
    end
  end
end
