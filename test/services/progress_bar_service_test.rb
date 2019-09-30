# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ProgressBarServiceTest < ActiveSupport::TestCase
    test 'check functionality of progressbar' do
      counter = 0
      total_count = 5
      DataCycleCore::ProgressBarService.for_shell(total_count) do |pb|
        total_count.times do
          pb.inc
          counter += 1
          assert_equal counter, pb.instance_variable_get(:@index)
        end
      end
    end

    test 'check functionality of progressbar above 50 items' do
      counter = 0
      total_count = 1000
      DataCycleCore::ProgressBarService.for_shell(total_count) do |pb|
        total_count.times do
          pb.inc
          counter += 1
          assert_equal counter, pb.instance_variable_get(:@index)
        end
      end
    end
  end
end
