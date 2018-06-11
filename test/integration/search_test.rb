# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class SearchTest < ActiveSupport::TestCase
    test 'test search utility functions' do
      template_data = DataCycleCore::CreativeWork.find_by(template: true, template_name: 'Bild2')
      data_set = DataCycleCore::CreativeWork.new
      data_set.schema = template_data.schema
      data_set.template_name = template_data.template_name
      data_set.save

      data_hash = {
        'caption' => 'Caption Test',
        'comment' => 'Comment Test',
        'description' => 'Description Test',
        'photographer' => 'Photographer Test'
      }
      data_set.set_data_hash(data_hash: data_hash)
      data_set.save
      data_set.set_search
      data_set.save

      assert(1, DataCycleCore::Search.count)
    end
  end
end
