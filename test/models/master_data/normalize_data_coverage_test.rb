# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module MasterData
    # Coverage for two NormalizeData class-method helpers - the recursive
    # parse_normalizable_fields template walk and the merge_street_streetnr action
    # rewrite. Both are pure hash transforms exercised with crafted inputs (no IO).
    class NormalizeDataCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
      Subject = DataCycleCore::MasterData::NormalizeData

      test 'parse_normalizable_fields walks nested properties and collects normalize ids' do
        template_hash = {
          'street' => { 'normalize' => 'street' },
          'geo' => { 'properties' => { 'lat' => { 'normalize' => 'latitude' } } }
        }

        result = Subject.send(:parse_normalizable_fields, nil, template_hash)

        assert_includes result, { 'id' => 'street', 'type' => 'STREET' }
        assert_includes result, { 'id' => 'geo/lat', 'type' => 'LATITUDE' }
      end

      test 'merge_street_streetnr rewrites the split action when the street name changed' do
        report = {
          'entry' => { 'fields' => [
            { 'type' => 'STREET', 'content' => 'Hauptstrasse' },
            { 'type' => 'STREETNR', 'content' => '5' }
          ] },
          'actionList' => [
            { 'taskType' => 'SPLIT', 'taskId' => 'Split_StreetStreetnr',
              'fieldsBefore' => [{ 'content' => 'Old Street' }],
              'fieldsAfter' => [{ 'type' => 'STREET', 'content' => 'ignored' }] }
          ]
        }

        result = Subject.send(:merge_street_streetnr, report)
        action = result['actionList'].first

        assert_equal 'ALTER', action['taskType']
        assert_equal 'Hauptstrasse 5', action['fieldsAfter'].first['content']
      end
    end
  end
end
