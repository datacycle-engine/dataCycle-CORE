# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class TimeseriesTransformationTest < DataCycleCore::TestCases::ActiveSupportTestCase
    THING_ID = SecureRandom.uuid
    TIMESTAMP = '2026-01-01T10:00:00Z'

    def transform(config, data)
      TimeseriesTransformation.new(config&.with_indifferent_access).apply(data)
    end

    def point(property:, value:, timestamp: TIMESTAMP)
      { thing_id: THING_ID, property:, timestamp:, value: }
    end

    test 'returns data unchanged when config is nil' do
      data = [point(property: 'visitors', value: 42)]

      assert_equal data, transform(nil, data)
    end

    test 'returns data unchanged when config is blank' do
      data = [point(property: 'visitors', value: 42)]

      assert_equal data, transform({}, data)
    end

    test 'returns zeros visitors when status matches closed' do
      config = { 'visitors' => [{ 'type' => 'zero_if', 'property' => 'status', 'values' => ['closed'] }] }
      data = [
        point(property: 'visitors', value: 99),
        point(property: 'status',   value: 'closed')
      ]
      result = transform(config, data)

      assert_equal 0, result.find { |d| d[:property] == 'visitors' }[:value]
      assert_equal 'closed', result.find { |d| d[:property] == 'status' }[:value]
    end

    test 'leaves visitors unchanged when status does not match' do
      config = { 'visitors' => [{ 'type' => 'zero_if', 'property' => 'status', 'values' => ['closed'] }] }
      data = [
        point(property: 'visitors', value: 42),
        point(property: 'status',   value: 'open')
      ]
      result = transform(config, data)

      assert_equal 42, result.find { |d| d[:property] == 'visitors' }[:value]
    end

    test 'leaves visitors unchanged when condition property is absent from payload' do
      config = { 'visitors' => [{ 'type' => 'zero_if', 'property' => 'status', 'values' => ['closed'] }] }
      data = [point(property: 'visitors', value: 55)]
      result = transform(config, data)

      assert_equal 55, result.find { |d| d[:property] == 'visitors' }[:value]
    end

    test 'returns only zero values at matching timestamp' do
      config = { 'visitors' => [{ 'type' => 'zero_if', 'property' => 'status', 'values' => ['closed'] }] }
      ts_closed = '2026-01-01T10:00:00Z'
      ts_open   = '2026-01-01T11:00:00Z'
      data = [
        point(property: 'visitors', value: 99, timestamp: ts_closed),
        point(property: 'status',   value: 'closed', timestamp: ts_closed),
        point(property: 'visitors', value: 30, timestamp: ts_open),
        point(property: 'status',   value: 'open', timestamp: ts_open)
      ]
      result = transform(config, data)
      visitors = result.select { |d| d[:property] == 'visitors' }

      assert_equal 0,  visitors.find { |d| d[:timestamp] == ts_closed }[:value]
      assert_equal 30, visitors.find { |d| d[:timestamp] == ts_open }[:value]
    end

    test 'accepts multiple condition values' do
      config = { 'visitors' => [{ 'type' => 'zero_if', 'property' => 'status', 'values' => ['closed', 'maintenance'] }] }
      data = [
        point(property: 'visitors', value: 10),
        point(property: 'status',   value: 'maintenance')
      ]
      result = transform(config, data)

      assert_equal 0, result.find { |d| d[:property] == 'visitors' }[:value]
    end

    test 'ignores unknown rule type and returns point unchanged' do
      config = { 'visitors' => [{ 'type' => 'unknown_rule', 'property' => 'status', 'values' => ['closed'] }] }
      data = [
        point(property: 'visitors', value: 77),
        point(property: 'status',   value: 'closed')
      ]
      result = transform(config, data)

      assert_equal 77, result.find { |d| d[:property] == 'visitors' }[:value]
    end
  end
end
