# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module ContentScore
      class EmbeddedTest < DataCycleCore::TestCases::ActiveSupportTestCase
        SUBJECT = DataCycleCore::Utility::ContentScore::Embedded
        KEY = 'embedded_key'

        def name_definition(method)
          {
            'content_score' => {
              'method' => method,
              'score_matrix' => {
                'Beschreibung' => { 'weight' => 0.6, 'min' => 10, 'max' => 200, 'optimal' => 100 },
                'Anreise' => { 'weight' => 0.4, 'min' => 5, 'max' => 100 }
              }
            }
          }
        end

        def type_definition(method)
          {
            'content_score' => {
              'method' => method,
              'score_matrix' => {
                'Beschreibung' => { 'weight' => 1.0, 'min' => 10, 'max' => 200 }
              }
            }
          }
        end

        def first_type_definition
          {
            'content_score' => {
              'method' => 'first_by_type_and_presence',
              'score_matrix' => {
                'group_1' => { 'weight' => 1.0, 'types' => ['Beschreibung'] }
              }
            }
          }
        end

        test 'by_name_and_length scores embedded items by sanitized description length' do
          parameters = { KEY => [{ 'name' => 'Beschreibung', 'description' => "<p>#{'a' * 80}</p>" }] }

          score = SUBJECT.by_name_and_length(definition: name_definition('by_name_and_length'), parameters:, key: KEY)

          assert_operator score, :>, 0
        end

        test 'by_name_and_presence scores embedded items by presence' do
          parameters = { KEY => [{ 'name' => 'Beschreibung', 'description' => 'text' }] }

          score = SUBJECT.by_name_and_presence(definition: name_definition('by_name_and_presence'), parameters:, key: KEY)

          assert_operator score, :>, 0
        end

        test 'by_type_and_presence runs over the score matrix' do
          parameters = { KEY => [{ 'type_of_information' => [], 'universal_classifications' => [], 'description' => 'text' }] }

          score = SUBJECT.by_type_and_presence(definition: type_definition('by_type_and_presence'), parameters:, key: KEY)

          assert_kind_of Numeric, score
        end

        test 'by_type_and_length runs over the score matrix' do
          parameters = { KEY => [{ 'type_of_information' => [], 'universal_classifications' => [], 'description' => 'text' }] }

          score = SUBJECT.by_type_and_length(definition: type_definition('by_type_and_length'), parameters:, key: KEY)

          assert_kind_of Numeric, score
        end

        test 'first_by_type_and_presence runs over the score matrix' do
          parameters = { KEY => [{ 'type_of_information' => [], 'universal_classifications' => [], 'description' => 'text' }] }

          score = SUBJECT.first_by_type_and_presence(definition: first_type_definition, parameters:, key: KEY)

          assert_kind_of Numeric, score
        end

        test 'to_tooltip builds tooltips for every supported method' do
          ['by_type_and_presence', 'by_type_and_length'].each do |method|
            assert SUBJECT.to_tooltip(nil, type_definition(method), :de)
          end

          ['by_name_and_length', 'by_name_and_presence'].each do |method|
            assert_kind_of ::String, SUBJECT.to_tooltip(nil, name_definition(method), :de)
          end

          assert SUBJECT.to_tooltip(nil, first_type_definition, :de)
        end

        test 'to_tooltip falls back to the base implementation for unknown methods' do
          assert_nothing_raised do
            SUBJECT.to_tooltip(nil, { 'content_score' => { 'method' => 'something_unknown' } }, :de)
          end
        end

        test 'minimum returns the lowest nested content score' do
          parameters = { KEY => [{ 'id' => nil, 'name' => 'Beschreibung', 'description' => 'text' }] }
          definition = name_definition('minimum').merge('template_name' => 'Artikel')

          assert_nothing_raised do
            SUBJECT.minimum(definition:, parameters:, key: KEY)
          end
        end
      end
    end
  end
end
