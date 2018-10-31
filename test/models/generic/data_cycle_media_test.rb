# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Generic
    class DataCycleMediaTest < ActiveSupport::TestCase
      def setup
        @asset_temp = DataCycleCore::Asset.count
      end

      test 'see what happens' do
        external_source = DataCycleCore::ExternalSource.find_by(name: 'DataCycle - Media')
        external_source.import

        assert_equal(3, DataCycleCore::Asset.count)
      end
    end
  end
end
