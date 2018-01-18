require 'test_helper'

module DataCycleCore
  class SearchTest < ActiveSupport::TestCase
    test 'test search utility functions' do
      template_cw_count = DataCycleCore::CreativeWork.count
      template_cwt_count = DataCycleCore::CreativeWork::Translation.count

      template_data = DataCycleCore::CreativeWork.find_by(template: true, headline: "Bild2", description: "ImageObject")
      validation_hash = template_data.metadata['validation']
      data_set = DataCycleCore::CreativeWork.new
      data_set.metadata = { 'validation' => validation_hash }
      data_set.save

      data_hash = {
        "caption" => "Caption Test",
        "comment" => "Comment Test",
        "description" => "Description Test",
        "photographer" => "Photographer Test"
      }
      data_set.set_data_hash(data_hash: data_hash)
      data_set.save
      data_set.set_search
      data_set.save

      # ap data_set.search_property_names
      # ap data_set.content_search
    end
  end
end
