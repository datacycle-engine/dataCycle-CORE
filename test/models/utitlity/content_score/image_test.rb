# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module ContentScore
      class ImageTest < DataCycleCore::TestCases::ActiveSupportTestCase
        before(:all) do
          @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Image Score Article' })
        end

        def subject
          DataCycleCore::Utility::ContentScore::Image
        end

        test 'to_tooltip renders the aspect ratio and score matrix as html' do
          definition = {
            'content_score' => {
              'method' => 'by_aspect_ratio',
              'aspect_ratio' => { 'min' => '1', 'max' => '2' },
              'score_matrix' => { 'name' => { 'min' => '1' } }
            }
          }

          tooltip = subject.to_tooltip(@content, definition, :de)

          assert_kind_of(::String, tooltip)
          assert_includes(tooltip, '<ul>')
        end

        test 'to_tooltip delegates to the base tooltip for other methods' do
          assert_nothing_raised do
            subject.to_tooltip(@content, { 'content_score' => { 'method' => 'by_quantity' } }, :de)
          end
        end
      end
    end
  end
end
