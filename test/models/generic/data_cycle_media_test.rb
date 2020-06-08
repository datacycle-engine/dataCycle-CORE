# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Generic
    class DataCycleMediaTest < ActiveSupport::TestCase
      def setup
        @asset_temp = DataCycleCore::Asset.count
      end

      test 'import dummy assets' do
        external_source = DataCycleCore::ExternalSystem.find_by(name: 'DataCycle - Media')
        external_source.import

        assert_equal(8, DataCycleCore::Asset.count)
        assert_equal(1, DataCycleCore::Audio.count)
        assert_equal(5, DataCycleCore::Image.count)
        assert_equal(1, DataCycleCore::Pdf.count)
        assert_equal(1, DataCycleCore::Video.count)
      end

      def teardown
        DataCycleCore::Asset.find_each(&:remove_file!)
      end
    end
  end
end
