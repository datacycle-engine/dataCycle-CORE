# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module ContentScore
      module Embedded
        class ByNameAndLength < DataCycleCore::TestCases::ActiveSupportTestCase
          test 'by_name_and_length works with name and text lengths' do
            key = 'additional_information'
            definition = { 'content_score' => { 'score_matrix' => { 'Beschreibung' => { 'min' => 10 }, 'Kurzbeschreibung' => { 'min' => 5 } } } }

            assert_equal 0, DataCycleCore::Utility::ContentScore::Embedded.by_name_and_length(key:, parameters: { 'additional_information' => [{ 'name' => 'Kurzbeschreibung', 'description' => '' }] }, definition:)
            assert_equal 0.5, DataCycleCore::Utility::ContentScore::Embedded.by_name_and_length(key:, parameters: { 'additional_information' => [{ 'name' => 'Kurzbeschreibung', 'description' => 'short' }] }, definition:)
            assert_equal 1, DataCycleCore::Utility::ContentScore::Embedded.by_name_and_length(key:, parameters: { 'additional_information' => [{ 'name' => 'Beschreibung', 'description' => 'long description' }, { 'name' => 'Kurzbeschreibung', 'description' => 'short' }] }, definition:)
          end

          test 'by_name_and_length works with custom weights' do
            key = 'additional_information'
            definition = { 'content_score' => { 'score_matrix' => { 'Beschreibung' => { 'min' => 10, 'weight' => 0.8 }, 'Kurzbeschreibung' => { 'min' => 5, 'weight' => 0.2 } } } }

            assert_equal 0, DataCycleCore::Utility::ContentScore::Embedded.by_name_and_length(key:, parameters: { 'additional_information' => [{ 'name' => 'Kurzbeschreibung', 'description' => '' }] }, definition:)
            assert_equal 0.2, DataCycleCore::Utility::ContentScore::Embedded.by_name_and_length(key:, parameters: { 'additional_information' => [{ 'name' => 'Kurzbeschreibung', 'description' => 'short' }] }, definition:)
            assert_equal 0.8, DataCycleCore::Utility::ContentScore::Embedded.by_name_and_length(key:, parameters: { 'additional_information' => [{ 'name' => 'Beschreibung', 'description' => 'long description' }] }, definition:)
            assert_equal 1, DataCycleCore::Utility::ContentScore::Embedded.by_name_and_length(key:, parameters: { 'additional_information' => [{ 'name' => 'Beschreibung', 'description' => 'long description' }, { 'name' => 'Kurzbeschreibung', 'description' => 'short' }] }, definition:)
          end

          test 'by_name_and_length works with custom weights as rational numbers' do
            key = 'additional_information'
            definition = { 'content_score' => { 'score_matrix' => { 'Beschreibung' => { 'min' => 10, 'weight' => '2/3' }, 'Kurzbeschreibung' => { 'min' => 5, 'weight' => '1/3' } } } }

            assert_equal 0, DataCycleCore::Utility::ContentScore::Embedded.by_name_and_length(key:, parameters: { 'additional_information' => [{ 'name' => 'Kurzbeschreibung', 'description' => '' }] }, definition:)
            assert_equal Rational(1, 3), DataCycleCore::Utility::ContentScore::Embedded.by_name_and_length(key:, parameters: { 'additional_information' => [{ 'name' => 'Kurzbeschreibung', 'description' => 'short' }] }, definition:)
            assert_equal Rational(2, 3), DataCycleCore::Utility::ContentScore::Embedded.by_name_and_length(key:, parameters: { 'additional_information' => [{ 'name' => 'Beschreibung', 'description' => 'long description' }] }, definition:)
            assert_equal 1, DataCycleCore::Utility::ContentScore::Embedded.by_name_and_length(key:, parameters: { 'additional_information' => [{ 'name' => 'Beschreibung', 'description' => 'long description' }, { 'name' => 'Kurzbeschreibung', 'description' => 'short' }] }, definition:)
          end
        end
      end
    end
  end
end
