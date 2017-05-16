require 'test_helper'

module DataCycleCore
  class CreativeWorkTest < ActiveSupport::TestCase

    def setup
      # load template, classifications
      template_yaml = Rails.root.join('..','setup_data','templates.yml')
      DataCycleCore::MasterData::ImportTemplates.new.import(template_yaml)
    end

    test "CreativeWork exists" do
      # load template
      # template_yaml = Rails.root.join('..','setup_data','templates.yml')
      # DataCycleCore::MasterData::ImportTemplates.new(template_yaml)

      data = DataCycleCore::CreativeWork.new
      assert_equal(data.class, DataCycleCore::CreativeWork)
    end



  end
end
