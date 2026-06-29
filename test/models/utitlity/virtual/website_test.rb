# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module Virtual
      class WebsiteTest < DataCycleCore::TestCases::ActiveSupportTestCase
        def subject
          DataCycleCore::Utility::Virtual::Website
        end

        test 'slugified_path returns nil when the recursive query yields no path' do
          content = struct_double(id: '00000000-0000-0000-0000-000000000001')

          ActiveRecord::Base.connection.stub(:select_all, select_all_result([])) do
            assert_nil(subject.slugified_path(content:))
          end
        end

        test 'slugified_path builds a slugified path from the ancestor webpages' do
          content = struct_double(id: '00000000-0000-0000-0000-000000000001')
          ancestor = struct_double(id: 'id-a', name: 'Child Page')
          relation = Class.new {
            def initialize(items) = (@items = items)
            def preload(*_args) = @items
          }.new([ancestor])

          ActiveRecord::Base.connection.stub(:select_all, select_all_result([['id-a', ['id-b']]])) do
            DataCycleCore::Thing.stub(:where, relation) do
              assert_equal('/child-page', subject.slugified_path(content:))
            end
          end
        end

        test 'slugified_path returns nil when an ancestor lookup fails' do
          content = struct_double(id: '00000000-0000-0000-0000-000000000001')

          ActiveRecord::Base.connection.stub(:select_all, select_all_result([['id-a', []]])) do
            DataCycleCore::Thing.stub(:where, ->(*) { raise ActiveRecord::RecordNotFound }) do
              assert_nil(subject.slugified_path(content:))
            end
          end
        end

        private

        def select_all_result(rows)
          Struct.new(:rows) {
            def cast_values = rows
          }.new(rows)
        end
      end
    end
  end
end
