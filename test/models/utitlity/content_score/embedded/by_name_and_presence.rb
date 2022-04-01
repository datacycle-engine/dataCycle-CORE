# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module ContentScore
      module Embedded
        class ByNameAndPresence < DataCycleCore::TestCases::ActiveSupportTestCase
          test 'by_name_and_presence works with name' do
            key = 'additional_information'
            definition = { 'content_score' => { 'score_matrix' => { 'Beschreibung' => nil, 'Kurzbeschreibung' => nil } } }

            assert_equal 0.5, DataCycleCore::Utility::ContentScore::Embedded.by_name_and_presence(key: key, parameters: { 'additional_information' => [{ 'name' => 'Kurzbeschreibung', 'description' => '' }] }, definition: definition)
            assert_equal 0.5, DataCycleCore::Utility::ContentScore::Embedded.by_name_and_presence(key: key, parameters: { 'additional_information' => [{ 'name' => 'Kurzbeschreibung', 'description' => 'short' }] }, definition: definition)
            assert_equal 1, DataCycleCore::Utility::ContentScore::Embedded.by_name_and_presence(key: key, parameters: { 'additional_information' => [{ 'name' => 'Beschreibung', 'description' => 'long description' }, { 'name' => 'Kurzbeschreibung', 'description' => 'short' }] }, definition: definition)
          end

          test 'by_name_and_presence works with custom weights' do
            key = 'additional_information'
            definition = { 'content_score' => { 'score_matrix' => { 'Beschreibung' => { 'weight' => 0.8 }, 'Kurzbeschreibung' => { 'weight' => 0.2 } } } }

            assert_equal 0.2, DataCycleCore::Utility::ContentScore::Embedded.by_name_and_presence(key: key, parameters: { 'additional_information' => [{ 'name' => 'Kurzbeschreibung', 'description' => 'short' }] }, definition: definition)
            assert_equal 0.8, DataCycleCore::Utility::ContentScore::Embedded.by_name_and_presence(key: key, parameters: { 'additional_information' => [{ 'name' => 'Beschreibung', 'description' => 'long description' }] }, definition: definition)
            assert_equal 1, DataCycleCore::Utility::ContentScore::Embedded.by_name_and_presence(key: key, parameters: { 'additional_information' => [{ 'name' => 'Beschreibung', 'description' => 'long description' }, { 'name' => 'Kurzbeschreibung', 'description' => 'short' }] }, definition: definition)
          end

          test 'by_name_and_presence works with custom weights as rational numbers' do
            key = 'additional_information'
            definition = { 'content_score' => { 'score_matrix' => { 'Beschreibung' => { 'weight' => '2/3' }, 'Kurzbeschreibung' => { 'weight' => '1/3' } } } }

            assert_equal Rational(1, 3), DataCycleCore::Utility::ContentScore::Embedded.by_name_and_presence(key: key, parameters: { 'additional_information' => [{ 'name' => 'Kurzbeschreibung', 'description' => 'short' }] }, definition: definition)
            assert_equal Rational(2, 3), DataCycleCore::Utility::ContentScore::Embedded.by_name_and_presence(key: key, parameters: { 'additional_information' => [{ 'name' => 'Beschreibung', 'description' => 'long description' }] }, definition: definition)
            assert_equal 1, DataCycleCore::Utility::ContentScore::Embedded.by_name_and_presence(key: key, parameters: { 'additional_information' => [{ 'name' => 'Beschreibung', 'description' => 'long description' }, { 'name' => 'Kurzbeschreibung', 'description' => 'short' }] }, definition: definition)
          end
        end
      end
    end
  end
end
