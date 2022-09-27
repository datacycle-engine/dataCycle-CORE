# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module ContentScore
      module Content
        class ByWeightMatrix < DataCycleCore::TestCases::ActiveSupportTestCase
          before(:all) do
            @content = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'TestBild 1' })
          end

          test 'by_weight_matrix works with normal matrix and presence' do
            @content.schema['features']['content_score'] = { 'module' => 'DataCycleCore::Utility::ContentScore::Content', 'method' => 'by_weight_matrix', 'parameters' => ['height', 'width'], 'weight_matrix' => { 'height' => '1/2', 'width' => '1/2' } }

            assert_equal 0, @content.calculate_content_score(nil, { 'width' => nil })
            assert_equal 0, @content.calculate_content_score(nil, { 'height' => nil })
            assert_equal 0.5, @content.calculate_content_score(nil, { 'width' => 0 })
            assert_equal 0.5, @content.calculate_content_score(nil, { 'height' => 0 })
            assert_equal 0.5, @content.calculate_content_score(nil, { 'height' => 100 })
            assert_equal 0.5, @content.calculate_content_score(nil, { 'height' => 100, 'width' => nil })
            assert_equal 1, @content.calculate_content_score(nil, { 'height' => 100, 'width' => 0 })
            assert_equal 1, @content.calculate_content_score(nil, { 'height' => 100, 'width' => 50 })
          end
        end
      end
    end
  end
end
