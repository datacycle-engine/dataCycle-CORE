# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module Compute
      # The ValueByPathExtension concern is mixed into the compute modules (Common, Classification, …)
      # as private class methods; we exercise them through Common via #send.
      class ValueByPathExtensionTest < DataCycleCore::TestCases::ActiveSupportTestCase
        def subject
          DataCycleCore::Utility::Compute::Common
        end

        def get_values(**args)
          subject.send(:get_values_from_hash, **args)
        end

        test 'get_values_from_hash reads a value nested under datahash' do
          assert_equal('from-datahash', get_values(data: { 'datahash' => { 'name' => 'from-datahash' } }, key_path: ['name']))
        end

        test 'get_values_from_hash reads a value nested under the current locale translations' do
          value = get_values(data: { 'translations' => { I18n.locale.to_s => { 'name' => 'from-translation' } } }, key_path: ['name'])

          assert_equal('from-translation', value)
        end

        test 'get_values_from_hash handles an empty active record relation' do
          assert_nil(get_values(data: DataCycleCore::Thing.none, key_path: ['name']))
        end

        test 'filtered_data keeps a matching hash and rejects a non-matching one' do
          filter = [{ 'type' => 'kind', 'value' => 'poi' }]

          assert_equal({ 'kind' => 'poi' }, subject.send(:filtered_data, data: { 'kind' => 'poi' }, filter:, current_key: 'place'))
          assert_equal({}, subject.send(:filtered_data, data: { 'kind' => 'event' }, filter:, current_key: 'place'))
        end

        test 'filtered_data selects matching entries from an array' do
          filter = [{ 'type' => 'kind', 'value' => 'poi' }]
          data = [{ 'kind' => 'poi' }, { 'kind' => 'event' }]

          assert_equal([{ 'kind' => 'poi' }], subject.send(:filtered_data, data:, filter:, current_key: 'place'))
        end

        test 'filtered_data returns scalar data unchanged' do
          assert_equal('scalar', subject.send(:filtered_data, data: 'scalar', filter: [{ 'type' => 'x' }], current_key: 'place'))
        end

        test 'data_in_filter? returns true for non-hash data or a blank key' do
          assert(subject.send(:data_in_filter?, nil, [], [{ 'type' => 'x' }]))
        end

        test 'data_in_filter? matches a simple key/value filter' do
          assert(subject.send(:data_in_filter?, 'name', { 'name' => 'X' }, [{ 'type' => 'name', 'value' => 'X' }]))
          assert_not(subject.send(:data_in_filter?, 'name', { 'name' => 'X' }, [{ 'type' => 'name', 'value' => 'Y' }]))
        end

        test 'data_in_filter? matches a size filter against the collection' do
          assert(subject.send(:data_in_filter?, 'items', { 'a' => 1 }, [{ 'type' => 'size', 'value' => 2 }], nil, [1, 2]))
        end

        test 'data_in_filter? matches a classification filter by resolved concept id' do
          DataCycleCore::Concept.stub(:by_full_paths, [struct_double(classification_id: 'cid-1')]) do
            filter = [{ 'type' => 'classification', 'value' => ['Tags > Tag 1'], 'key' => ['tags'] }]

            assert(subject.send(:data_in_filter?, 'place', { 'tags' => ['cid-1'] }, filter))
          end
        end

        test 'data_in_filter? skips a classification filter that resolves to no concept' do
          DataCycleCore::Concept.stub(:by_full_paths, []) do
            filter = [{ 'type' => 'classification', 'value' => ['Unknown > Path'], 'key' => ['tags'] }]

            assert(subject.send(:data_in_filter?, 'place', { 'tags' => ['cid-1'] }, filter))
          end
        end

        test 'clone_attribute_value builds a schedule external reference for embedded schedules' do
          cloned = subject.send(:clone_attribute_value, value: { 'start_time' => { 'time' => '2025-06-15T09:00:00Z' }, 'external_key' => 'orig' }, external_key_prefix: ['prefix'])

          assert(cloned.key?('external_key'))
          assert(cloned['external_key'].start_with?('prefix_'))
        end
      end
    end
  end
end
