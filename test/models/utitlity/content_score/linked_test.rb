# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module ContentScore
      class LinkedTest < DataCycleCore::TestCases::ActiveSupportTestCase
        def subject
          DataCycleCore::Utility::ContentScore::Linked
        end

        test 'by_first_linked_score returns 0 without linked ids' do
          assert_equal(0, subject.by_first_linked_score(parameters: { 'authors' => [] }, key: 'authors'))
        end

        test 'by_first_linked_score scales the internal score of the first linked thing' do
          DataCycleCore::Thing.stub(:find_by, struct_double(internal_content_score: 80)) do
            value = subject.by_first_linked_score(parameters: { 'authors' => ['id-1'] }, key: 'authors')

            assert_in_delta(0.8, value)
          end
        end

        test 'by_linked_score_and_weights picks the weight for the count of high-scoring links' do
          definition = { 'content_score' => { 'min_score' => 50, 'weight_matrix' => { '1' => '0.5' } } }
          linked = [struct_double(internal_content_score: 80), struct_double(internal_content_score: 30)]

          DataCycleCore::Thing.stub(:by_ordered_values, linked) do
            value = subject.by_linked_score_and_weights(definition:, parameters: { 'authors' => ['id-1', 'id-2'] }, key: 'authors')

            assert_in_delta(0.5, value)
          end
        end

        test 'by_linked_score_and_weights falls back to the many weight' do
          definition = { 'content_score' => { 'min_score' => 50, 'weight_matrix' => { 'many' => '1' } } }
          linked = [struct_double(internal_content_score: 80), struct_double(internal_content_score: 90)]

          DataCycleCore::Thing.stub(:by_ordered_values, linked) do
            value = subject.by_linked_score_and_weights(definition:, parameters: { 'authors' => ['id-1', 'id-2'] }, key: 'authors')

            assert_in_delta(1.0, value)
          end
        end

        test 'by_linked_score_and_weights scores 0 without a matching weight' do
          definition = { 'content_score' => { 'min_score' => 50, 'weight_matrix' => { '1' => '0.5' } } }
          linked = [struct_double(internal_content_score: 10)]

          DataCycleCore::Thing.stub(:by_ordered_values, linked) do
            value = subject.by_linked_score_and_weights(definition:, parameters: { 'authors' => ['id-1'] }, key: 'authors')

            assert_equal(0, value)
          end
        end

        test 'by_linked_weight_matrix averages the weighted scores of the linked things' do
          item = Class.new {
            def property_names = ['rating']
            def get_data_hash_partial(_keys) = { 'rating' => 5 }
            def content_score_property_names = []
          }.new
          definition = { 'content_score' => { 'weight_matrix' => { 'rating' => '1' } } }

          DataCycleCore::Thing.stub(:where, [item]) do
            value = subject.by_linked_weight_matrix(parameters: { 'items' => ['id-1'] }, definition:, key: 'items')

            assert_in_delta(1.0, value)
          end
        end

        test 'by_linked_weight_matrix returns 0 without linked items' do
          DataCycleCore::Thing.stub(:where, []) do
            value = subject.by_linked_weight_matrix(parameters: { 'items' => [] }, definition: { 'content_score' => { 'weight_matrix' => {} } }, key: 'items')

            assert_equal(0, value)
          end
        end

        test 'to_tooltip renders the weight matrix as html' do
          definition = { 'content_score' => { 'method' => 'by_linked_score_and_weights', 'min_score' => 50, 'weight_matrix' => { '1' => '0.5', 'many' => '1' } } }

          tooltip = subject.to_tooltip(nil, definition, :de)

          assert_includes(tooltip, '<ul>')
        end
      end
    end
  end
end
