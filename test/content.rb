require 'test_helper'

module DataCycleCore
  class CreativeWorkTest < ActiveSupport::TestCase
    test "make sure config.i18n.fallback is set to false" do
      template = DataCycleCore::CreativeWork.find_by(template: true, headline: "BildMinimal", description: "ImageObject")
      validation = template.metadata['validation']
      data_set = DataCycleCore::CreativeWork.new
      data_set.metadata = { 'validation' => validation }
      data_set.save

      data_hash_de = {"headline" => "Dies ist ein Test!", "test_content" => "Deutsch"}
      data_hash_en = {"headline" => "This is a Test!", "test_content" => "English"}

      data_set.set_data_hash(data_hash: data_hash_de)
      data_set.save
      assert_equal(data_hash_de, data_set.get_data_hash)

      I18n.with_locale(:en) do
        data_set.set_data_hash(data_hash: data_hash_en)
        data_set.save
        assert_equal(data_hash_en, data_set.get_data_hash)
      end

      assert_equal(data_hash_de, data_set.get_data_hash)
      assert_equal(data_hash_en, I18n.with_locale(:en){data_set.get_data_hash})
    end
  end
end
