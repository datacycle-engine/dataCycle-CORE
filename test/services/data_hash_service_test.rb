# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class DataHashServiceTest < DataCycleCore::TestCases::ActiveSupportTestCase
    test 'permitted_content_params returns empty params for an unsupported template argument' do
      result = DataCycleCore::DataHashService.new.permitted_content_params(123, { 'a' => 1 })

      assert_kind_of ActionController::Parameters, result
      assert_empty result.to_unsafe_h
    end

    test 'flatten_datahash_translations_recursive merges datahash and translations' do
      result = DataCycleCore::DataHashService.flatten_datahash_translations_recursive(
        { datahash: { 'a' => 1 }, translations: { I18n.locale => { 'b' => 2 } } }
      )

      assert_equal 1, result['a']
      assert_equal 2, result['b']
    end

    test 'flatten_datahash_translations_recursive flattens arrays of id-only hashes' do
      result = DataCycleCore::DataHashService.flatten_datahash_translations_recursive(
        { datahash: { 'items' => [{ 'id' => 'thing-1' }] }, translations: {} }
      )

      assert_equal ['thing-1'], result['items']
    end

    test 'none_by_property_type returns an empty relation per property type' do
      assert_equal 0, DataCycleCore::DataHashService.none_by_property_type('linked').count
      assert_equal 0, DataCycleCore::DataHashService.none_by_property_type('classification').count
      assert_equal 0, DataCycleCore::DataHashService.none_by_property_type('schedule').count
      assert_equal 0, DataCycleCore::DataHashService.none_by_property_type('timeseries').count
    end

    test 'flatten_datahash_value casts scalar values according to their type' do
      schema = {
        'properties' => {
          'price' => { 'type' => 'number', 'validations' => { 'format' => 'float' } },
          'count' => { 'type' => 'number' },
          'flag' => { 'type' => 'boolean' },
          'tbl' => { 'type' => 'table' }
        }
      }

      result = DataCycleCore::DataHashService.flatten_datahash_value(
        { 'price' => '1.5', 'count' => '3', 'flag' => 'true', 'tbl' => '{"a":1}' },
        schema
      )

      assert_in_delta 1.5, result['price']
      assert_equal 3, result['count']
      assert result['flag']
      assert_equal({ 'a' => 1 }, result['tbl'])
    end

    test 'flatten_datahash_value recurses into object properties' do
      schema = { 'properties' => { 'obj' => { 'type' => 'object', 'properties' => { 'inner' => { 'type' => 'string' } } } } }

      result = DataCycleCore::DataHashService.flatten_datahash_value({ 'obj' => { 'inner' => 'value' } }, schema)

      assert_equal({ 'inner' => 'value' }, result['obj'])
    end

    test 'flatten_datahash_value compacts the value array of a hash property' do
      schema = { 'properties' => { 'prop' => { 'type' => 'string' } } }

      result = DataCycleCore::DataHashService.flatten_datahash_value({ 'prop' => { 'value' => ['a', ''] } }, schema)

      assert_equal ['a'], result['prop']['value']
    end

    test 'flatten_datahash_value nils out blank geographic values' do
      schema = { 'properties' => { 'location' => { 'type' => 'geographic' } } }

      result = DataCycleCore::DataHashService.flatten_datahash_value({ 'location' => '' }, schema)

      assert_nil result['location']
    end
  end
end
