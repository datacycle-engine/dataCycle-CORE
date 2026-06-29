# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module ContentScore
      class ContentTest < DataCycleCore::TestCases::ActiveSupportTestCase
        before(:all) do
          @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Content Score Article' })
        end

        def subject
          DataCycleCore::Utility::ContentScore::Content
        end

        def presence_only_content
          Class.new { def content_score_property_names = [] }.new
        end

        test 'by_field_presence_or_method caps the score by the score matrix when a group is incomplete' do
          content = presence_only_content
          definition = { 'content_score' => { 'score_matrix' => { '0.5' => ['name', 'image'] } } }

          value = subject.by_field_presence_or_method(content:, parameters: { 'name' => 'present', 'image' => [] }, definition:)

          assert_in_delta(0.5, value)
        end

        test 'by_field_presence_or_method returns the minimum value when the cap reaches zero' do
          content = presence_only_content
          definition = { 'content_score' => { 'score_matrix' => { '0' => ['name', 'image'] } } }

          value = subject.by_field_presence_or_method(content:, parameters: { 'name' => 'present', 'image' => [] }, definition:)

          assert_equal(0, value)
        end

        test 'to_tooltip renders the weight and score matrices as html' do
          definition = {
            'content_score' => {
              'method' => 'by_weight_matrix',
              'weight_matrix' => { 'name' => '1' },
              'score_matrix' => { '0.5' => ['name'] },
              'parameters' => ['name']
            }
          }

          tooltip = subject.to_tooltip(@content, definition, :de)

          assert_kind_of(::String, tooltip)
          assert_includes(tooltip, '<ul>')
        end
      end
    end
  end
end
