# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Generic
    class DataCycleMediaTest < ActiveSupport::TestCase
      def setup
        @cw_temp = DataCycleCore::CreativeWork.where(template: false).count
      end

      # test 'perform import' do
      #   options = {
      #     max_count: 1,
      #     mode: 'full'
      #   }
      #
      #   external_source = DataCycleCore::ExternalSource.find_by(name: 'Medienarchiv')
      #   external_source.download(options)
      #   external_source.import(options)
      #
      #   assert_equal(2, DataCycleCore::CreativeWork.where(template: false).count)
      # end
    end
  end
end
