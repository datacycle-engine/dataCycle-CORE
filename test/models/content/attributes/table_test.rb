# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'

module DataCycleCore
  module Content
    module Attributes
      class TableTest < DataCycleCore::TestCases::ActiveSupportTestCase
        test 'create table with initial data' do
          table_data = [
            ['A', 'B', 'C'],
            ['1', '2', '3'],
            ['4', '5', '6']
          ]

          content = DataCycleCore::TestPreparations.create_content(
            template_name: 'Table',
            data_hash: {
              name: 'Table 1',
              table_data:
            }
          )

          assert_equal table_data, content.table_data

          table_data = [
            ['A', 'B', 'C'],
            [1, 2, 3]
          ]

          content.set_data_hash(data_hash: {
            table_data:
          })

          assert_equal table_data&.map { |v| v&.map(&:to_s) }, content.table_data
        end
      end
    end
  end
end
