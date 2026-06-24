# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module ContentScore
      module Image
        class ByAspectRatio < DataCycleCore::TestCases::ActiveSupportTestCase
          before(:all) do
            @image_hashes = {
              0 => [
                { 'width' => nil },
                { 'width' => 0 },
                { 'height' => nil },
                { 'height' => 0 },
                { 'width' => nil, 'height' => nil },
                { 'width' => nil, 'height' => 0 },
                { 'width' => 0, 'height' => nil },
                { 'width' => 0, 'height' => 0 },
                { 'width' => 400, 'height' => 0 },
                { 'width' => 0, 'height' => 10 },
                { 'width' => 400, 'height' => 100 },
                { 'width' => 400, 'height' => 200 },
                { 'width' => 400, 'height' => 400 },
                { 'width' => 400, 'height' => 500 }
              ],
              1 => [
                { 'width' => 1200, 'height' => 900 },
                { 'width' => 2400, 'height' => 1800 }
              ]
            }
          end

          test 'by_aspect_ratio works with only aspect ratio as int' do
            definition = { 'content_score' => { 'aspect_ratio' => { 'min' => Rational(4, 3), 'max' => Rational(4, 3) } } }

            @image_hashes.each do |key, value|
              value.each { |v| assert_equal(key, DataCycleCore::Utility::ContentScore::Image.by_aspect_ratio(parameters: v, definition:)) }
            end
          end

          test 'by_aspect_ratio works with aspect ratio as string' do
            definition = { 'content_score' => { 'aspect_ratio' => { 'min' => '4/3', 'max' => '4/3' } } }

            @image_hashes.each do |key, value|
              value.each { |v| assert_equal(key, DataCycleCore::Utility::ContentScore::Image.by_aspect_ratio(parameters: v, definition:)) }
            end
          end

          test 'by_aspect_ratio works with aspect ratio min and max' do
            definition = { 'content_score' => { 'aspect_ratio' => { 'min' => '4/3', 'max' => '4/3' } } }

            @image_hashes.each do |key, value|
              value.each { |v| assert_equal(key, DataCycleCore::Utility::ContentScore::Image.by_aspect_ratio(parameters: v, definition:)) }
            end
          end

          test 'by_aspect_ratio works with only min height' do
            definition = { 'content_score' => { 'score_matrix' => { 'width' => { 'min' => 450 } } } }

            @image_hashes.each do |key, value|
              value.each { |v| assert_equal(key, DataCycleCore::Utility::ContentScore::Image.by_aspect_ratio(parameters: v, definition:)) }
            end
          end
        end
      end
    end
  end
end
