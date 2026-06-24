# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  GeocodeFeatureGeoPoint = Struct.new(:x, :y)

  class DummyGeocodeFeature
    def initialize(enabled: true, result: nil, error: nil)
      @enabled = enabled
      @result = result
      @error = error
    end

    def enabled?
      @enabled
    end

    def address_source
      'address'
    end

    def geocode_address(_address_hash)
      raise @error if @error.present?

      @result
    end

    def geodata_to_attributes(geodata)
      { longitude: geodata.x, latitude: geodata.y }
    end
  end

  class GenericCommonFunctionsTest < ActiveSupport::TestCase
    SUBJECT = DataCycleCore::Generic::Common::Functions

    test 'event_schedule returns data_hash unchanged when event_period is blank' do
      data_hash = { 'name' => 'event without period' }

      assert_equal data_hash, SUBJECT.event_schedule(data_hash, ->(_) {})
    end

    test 'event_schedule creates schedule with duration from event_period' do
      data_hash = {
        'name' => 'simple event',
        'event_period' => {
          'start_date' => '2026-01-01T10:00:00+01:00',
          'end_date' => '2026-01-01T12:00:00+01:00'
        }
      }

      result = SUBJECT.event_schedule(data_hash, ->(_) {})
      schedule = result['event_schedule'].first

      assert_equal 1, result['event_schedule'].size
      assert_equal 2.hours.to_i, schedule['duration']
      assert_equal '2026-01-01T10:00:00+01:00'.in_time_zone, schedule['dtstart']
      assert_equal '2026-01-01T12:00:00+01:00'.in_time_zone, schedule['dtend']
      assert_equal Time.zone.name, schedule.dig('start_time', 'zone')
      assert_equal Time.zone.name, schedule.dig('end_time', 'zone')
    end

    test 'event_schedule creates recurring schedule from sub events' do
      data_hash = {
        'name' => 'recurring event',
        'event_period' => {
          'start_date' => '2026-01-01T10:00:00+01:00',
          'end_date' => '2026-01-10T12:00:00+01:00'
        }
      }
      sub_events = [
        { 'start_date' => '2026-01-05T10:00:00+01:00', 'end_date' => '2026-01-05T11:00:00+01:00' },
        { 'event_period' => { 'start_date' => '2026-01-06T10:00:00+01:00' } }
      ]

      result = SUBJECT.event_schedule(data_hash, ->(_) { sub_events })
      schedule = result['event_schedule'].first

      assert_equal 1.hour.to_i, schedule['duration']
      assert_equal '2026-01-01T10:00:00+01:00'.in_time_zone, schedule['dtstart']
      assert_equal 2, schedule['rtimes'].size
      assert_equal '2026-01-05T10:00:00+01:00'.in_time_zone, schedule['rtimes'].first['time'].in_time_zone
    end

    test 'extension_to_mimetype adds content type for known extension' do
      data_hash = { 'url' => 'https://example.com/file.pdf' }

      result = SUBJECT.extension_to_mimetype(data_hash, 'content_type', ->(_) { 'pdf' })

      assert_equal 'application/pdf', result['content_type']
    end

    test 'extension_to_mimetype replaces application with specific type' do
      data_hash = {}

      result = SUBJECT.extension_to_mimetype(data_hash, 'content_type', ->(_) { 'pdf' }, 'document')

      assert_equal 'document/pdf', result['content_type']
    end

    test 'extension_to_mimetype returns data_hash unchanged for blank extension' do
      data_hash = { 'url' => 'https://example.com/file' }

      assert_equal data_hash, SUBJECT.extension_to_mimetype(data_hash, 'content_type', ->(_) {})
    end

    test 'extension_to_mimetype skips unknown extensions' do
      data_hash = { 'url' => 'https://example.com/file.zzzzz' }

      result = SUBJECT.extension_to_mimetype(data_hash, 'content_type', ->(_) { 'zzzzz' })

      assert_not result.key?('content_type')
    end

    test 'geocode returns data_hash unchanged when feature is disabled' do
      data_hash = { 'address' => { 'street_address' => 'Hauptplatz 1' } }

      DataCycleCore::Feature.stub(:[], DummyGeocodeFeature.new(enabled: false)) do
        assert_equal data_hash, SUBJECT.geocode(data_hash)
      end
    end

    test 'geocode returns data_hash unchanged when condition function returns false' do
      data_hash = { 'address' => { 'street_address' => 'Hauptplatz 1' } }
      feature = DummyGeocodeFeature.new(result: GeocodeFeatureGeoPoint.new(16.1, 47.2))

      DataCycleCore::Feature.stub(:[], feature) do
        assert_equal data_hash, SUBJECT.geocode(data_hash, ->(_) { false })
      end
    end

    test 'geocode returns data_hash unchanged when address params are blank' do
      data_hash = { 'address' => { 'street_address' => '' }, 'name' => 'no address' }
      feature = DummyGeocodeFeature.new(result: GeocodeFeatureGeoPoint.new(16.1, 47.2))

      DataCycleCore::Feature.stub(:[], feature) do
        assert_equal data_hash, SUBJECT.geocode(data_hash)
      end
    end

    test 'geocode merges geocoded attributes into data_hash' do
      data_hash = { 'address' => { 'street_address' => 'Hauptplatz 1' } }
      feature = DummyGeocodeFeature.new(result: GeocodeFeatureGeoPoint.new(16.1, 47.2))

      DataCycleCore::Feature.stub(:[], feature) do
        result = SUBJECT.geocode(data_hash)

        assert_in_delta 16.1, result['longitude']
        assert_in_delta 47.2, result['latitude']
        assert_equal data_hash['address'], result['address']
      end
    end

    test 'geocode returns data_hash unchanged when endpoint raises an error' do
      data_hash = { 'address' => { 'street_address' => 'Hauptplatz 1' } }
      error = DataCycleCore::Generic::Common::Error::EndpointError.new('geocoder unavailable')
      feature = DummyGeocodeFeature.new(error:)

      DataCycleCore::Feature.stub(:[], feature) do
        assert_equal data_hash, SUBJECT.geocode(data_hash)
      end
    end

    test 'add_external_system_data appends external_system_data entry with prefix' do
      data = { 'source' => { 'name' => 'other-system', 'id' => '123' } }

      result = SUBJECT.add_external_system_data(data, ['source', 'name'], ['source', 'id'], 'prefix-')
      expected = {
        'identifier' => 'other-system',
        'external_key' => 'prefix-123',
        'sync_type' => 'duplicate'
      }

      assert_equal [expected], result['external_system_data']
    end

    test 'add_external_system_data appends to existing external_system_data' do
      existing = { 'identifier' => 'existing', 'external_key' => 'abc', 'sync_type' => 'duplicate' }
      data = { 'name' => 'sys', 'id' => '1', 'external_system_data' => [existing] }

      result = SUBJECT.add_external_system_data(data, 'name', 'id')

      assert_equal 2, result['external_system_data'].size
      assert_equal existing, result['external_system_data'].first
      assert_equal '1', result['external_system_data'].last['external_key']
    end

    test 'add_external_system_data returns data unchanged when name or key is missing' do
      data = { 'id' => '123' }

      result = SUBJECT.add_external_system_data(data, 'name', 'id')

      assert_not result.key?('external_system_data')
    end

    test 'add_ext_key_and_system_data sets external_key and duplicates' do
      external_system = Struct.new(:identifier).new('my-system')
      data = { 'keys' => ['key-1', nil, 'key-2', 'key-1'] }

      result = SUBJECT.add_ext_key_and_system_data(data, external_system, ->(d) { d['keys'] })
      expected = {
        'identifier' => 'my-system',
        'external_key' => 'key-2',
        'sync_type' => 'duplicate'
      }

      assert_equal 'key-1', result['external_key']
      assert_equal [expected], result['external_system_data']
    end

    test 'add_ext_key_and_system_data returns data unchanged when function returns no values' do
      external_system = Struct.new(:identifier).new('my-system')
      data = { 'keys' => [] }

      result = SUBJECT.add_ext_key_and_system_data(data, external_system, ->(d) { d['keys'] })

      assert_not result.key?('external_key')
      assert_not result.key?('external_system_data')
    end
  end
end
