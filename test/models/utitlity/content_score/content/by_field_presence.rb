# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module ContentScore
      module Content
        class ByFieldPresence < DataCycleCore::TestCases::ActiveSupportTestCase
          before(:all) do
            @content = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'TestBild 1' })
          end

          test 'by_field_presence works with score_matrix and presence' do
            @content.schema['features']['content_score'] = { 'module' => 'DataCycleCore::Utility::ContentScore::Content', 'method' => 'by_field_presence', 'parameters' => ['height', 'width'], 'score_matrix' => { 0 => ['height'], 0.4 => ['width'] } }

            assert_equal 0, @content.calculate_content_score(nil, { 'width' => nil })
            assert_equal 0, @content.calculate_content_score(nil, { 'height' => nil })
            assert_equal 0, @content.calculate_content_score(nil, { 'width' => 0 })
            assert_equal 0, @content.calculate_content_score(nil, { 'width' => 50 })
            assert_equal 0.4, @content.calculate_content_score(nil, { 'height' => 0 })
            assert_equal 0.4, @content.calculate_content_score(nil, { 'height' => 100 })
            assert_equal 0.4, @content.calculate_content_score(nil, { 'height' => 100, 'width' => nil })
            assert_equal 1, @content.calculate_content_score(nil, { 'height' => 100, 'width' => 0 })
            assert_equal 1, @content.calculate_content_score(nil, { 'height' => 100, 'width' => 50 })
          end
        end
      end
    end
  end
end
