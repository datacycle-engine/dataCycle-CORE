# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module ContentScore
      class ObjectTest < DataCycleCore::TestCases::ActiveSupportTestCase
        def subject
          DataCycleCore::Utility::ContentScore::Object
        end

        test 'by_attribute_and_presence weights each present attribute equally without configured weights' do
          definition = { 'content_score' => { 'score_matrix' => { 'a' => {}, 'b' => {} } } }
          parameters = { 'address' => { 'a' => 'present', 'b' => nil } }

          value = subject.by_attribute_and_presence(definition:, parameters:, key: 'address')

          assert_in_delta(0.5, value.to_f)
        end

        test 'by_attribute_and_presence uses configured weights when present' do
          definition = { 'content_score' => { 'score_matrix' => { 'a' => { 'weight' => '0.5' }, 'b' => { 'weight' => 0.5 } } } }
          parameters = { 'address' => { 'a' => 'present' } }

          value = subject.by_attribute_and_presence(definition:, parameters:, key: 'address')

          assert_in_delta(0.5, value.to_f)
        end

        test 'to_tooltip renders the weighted attributes as html' do
          definition = {
            'content_score' => { 'method' => 'by_attribute_and_presence', 'score_matrix' => { 'a' => { 'weight' => '0.5' } } },
            'properties' => { 'a' => { 'label' => 'Attribute A' } }
          }

          tooltip = subject.to_tooltip(nil, definition, :de)

          assert_includes(tooltip.join, 'Attribute A')
        end

        test 'to_tooltip delegates to the base tooltip for other methods' do
          assert_nothing_raised do
            subject.to_tooltip(nil, { 'content_score' => { 'method' => 'by_quantity' } }, :de)
          end
        end
      end
    end
  end
end
