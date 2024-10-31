# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'
require 'helpers/minitest_spec_helper'

describe DataCycleCore::Generic::Common::OpeningHours do
  include DataCycleCore::MinitestSpecHelper

  subject do
    DataCycleCore::Generic::Common::OpeningHours
  end

  def days_to_ids(days)
    translate_days = { 'Monday' => 'Montag', 'Tuesday' => 'Dienstag', 'Wednesday' => 'Mittwoch', 'Thursday' => 'Donnerstag', 'Friday' => 'Freitag', 'Saturday' => 'Samstag', 'Sunday' => 'Sonntag' }
    translate_days
      .select { |_key, value| days.include?(value) }
      .map { |key, value| { key => DataCycleCore::ClassificationAlias.for_tree('Wochentage').find_by(name: value).classifications.first.id } }
      .reduce(&:merge)
      .values
  end

  describe 'import google format from wogehmahin' do
    let(:empty_record) do
      {
        'Monday' => [{ 'open' => nil, 'close' => nil, 'text' => nil }],
        'Tuesday' => [{ 'open' => nil, 'close' => nil, 'text' => nil }],
        'Wednesday' => [{ 'open' => nil, 'close' => nil, 'text' => nil }],
        'Thursday' => [{ 'open' => nil, 'close' => nil, 'text' => nil }],
        'Friday' => [{ 'open' => nil, 'close' => nil, 'text' => nil }],
        'Saturday' => [{ 'open' => nil, 'close' => nil, 'text' => nil }],
        'Sunday' => [{ 'open' => nil, 'close' => nil, 'text' => nil }]
      }
    end

    let(:one_record) do
      {
        'Monday' => [{ 'open' => '10:00:00', 'close' => '22:00:00', 'text' => nil }],
        'Tuesday' => [{ 'open' => '10:00:00', 'close' => '22:00:00', 'text' => nil }],
        'Wednesday' => [{ 'open' => '10:00:00', 'close' => '22:00:00', 'text' => nil }],
        'Thursday' => [{ 'open' => '10:00:00', 'close' => '22:00:00', 'text' => nil }],
        'Friday' => [{ 'open' => '10:00:00', 'close' => '22:00:00', 'text' => nil }],
        'Saturday' => [{ 'open' => nil, 'close' => nil, 'text' => nil }],
        'Sunday' => [{ 'open' => nil, 'close' => nil, 'text' => nil }]
      }
    end

    let(:one_record_wrong_time_format) do
      {
        'Monday' => [{ 'open' => '00:10:00', 'close' => '00:22:00', 'text' => nil }],
        'Tuesday' => [{ 'open' => '00:10:00', 'close' => '00:22:00', 'text' => nil }],
        'Wednesday' => [{ 'open' => '00:10:00', 'close' => '00:22:00', 'text' => nil }],
        'Thursday' => [{ 'open' => '00:10:00', 'close' => '00:22:00', 'text' => nil }],
        'Friday' => [{ 'open' => '00:10:00', 'close' => '00:22:00', 'text' => nil }],
        'Saturday' => [{ 'open' => nil, 'close' => nil, 'text' => nil }],
        'Sunday' => [{ 'open' => nil, 'close' => nil, 'text' => nil }]
      }
    end

    let(:one_record_transformed) do
      [{
        'day_of_week' => days_to_ids(['Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag']),
        'validity' => nil,
        'time' => [{ 'opens' => '10:00', 'closes' => '22:00' }]
      }]
    end

    let(:two_records) do
      {
        'Monday' => [{ 'open' => '10:00:00', 'close' => '22:00:00', 'text' => nil }],
        'Tuesday' => [{ 'open' => '10:00:00', 'close' => '22:00:00', 'text' => nil }],
        'Wednesday' => [{ 'open' => '10:00:00', 'close' => '22:00:00', 'text' => nil }],
        'Thursday' => [{ 'open' => '10:00:00', 'close' => '22:00:00', 'text' => nil }],
        'Friday' => [{ 'open' => '10:00:00', 'close' => '24:00:00', 'text' => nil }],
        'Saturday' => [{ 'open' => nil, 'close' => nil, 'text' => nil }],
        'Sunday' => [{ 'open' => nil, 'close' => nil, 'text' => nil }]
      }
    end

    let(:two_records_transformed) do
      [{
        'day_of_week' => days_to_ids(['Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag']),
        'validity' => nil,
        'time' => [{ 'opens' => '10:00', 'closes' => '22:00' }]
      }, {
        'day_of_week' => days_to_ids(['Freitag']),
        'validity' => nil,
        'time' => [{ 'opens' => '22:00', 'closes' => '0:00' }]
      }]
    end

    let(:three_records) do
      {
        'Monday' => [{ 'open' => '10:00:00', 'close' => '22:00:00', 'text' => nil }],
        'Tuesday' => [{ 'open' => '07:00:00', 'close' => '22:00:00', 'text' => nil }],
        'Wednesday' => [{ 'open' => '07:00:00', 'close' => '22:00:00', 'text' => nil }],
        'Thursday' => [{ 'open' => '10:00:00', 'close' => '22:00:00', 'text' => nil }],
        'Friday' => [{ 'open' => '10:00:00', 'close' => '24:00:00', 'text' => nil }],
        'Saturday' => [{ 'open' => nil, 'close' => nil, 'text' => nil }],
        'Sunday' => [{ 'open' => nil, 'close' => nil, 'text' => nil }]
      }
    end

    let(:tree_records_transformed) do
      [{
        'day_of_week' => days_to_ids(['Dienstag', 'Mittwoch']),
        'validity' => nil,
        'time' => [{ 'opens' => '7:00', 'closes' => '10:00' }]
      }, {
        'day_of_week' => days_to_ids(['Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag']),
        'validity' => nil,
        'time' => [{ 'opens' => '10:00', 'closes' => '22:00' }]
      }, {
        'day_of_week' => days_to_ids(['Freitag']),
        'validity' => nil,
        'time' => [{ 'opens' => '22:00', 'closes' => '0:00' }]
      }]
    end

    let(:three_records_string_output) do
      {
        'Montag' => '10:00 - 22:00',
        'Dienstag' => '7:00 - 22:00',
        'Mittwoch' => '7:00 - 22:00',
        'Donnerstag' => '10:00 - 22:00',
        'Freitag' => '10:00 - 0:00',
        'Samstag' => 'geschlossen',
        'Sonntag' => 'geschlossen'
      }
    end

    let(:three_records2) do
      {
        'Monday' => [{ 'open' => '10:00:00', 'close' => '12:00:00', 'text' => nil }],
        'Tuesday' => [{ 'open' => '12:00:00', 'close' => '14:00:00', 'text' => nil }],
        'Wednesday' => [{ 'open' => '14:00:00', 'close' => '16:00:00', 'text' => nil }],
        'Thursday' => [{ 'open' => '10:00:00', 'close' => '14:00:00', 'text' => nil }],
        'Friday' => [{ 'open' => '10:00:00', 'close' => '12:00:00', 'text' => nil }, { 'open' => '14:00:00', 'close' => '16:00:00', 'text' => nil }],
        'Saturday' => [{ 'open' => '12:00:00', 'close' => '16:00:00', 'text' => nil }],
        'Sunday' => [{ 'open' => '10:00:00', 'close' => '16:00:00', 'text' => nil }]
      }
    end

    let(:three_records2_string_output) do
      {
        'Montag' => '10:00 - 12:00',
        'Dienstag' => '12:00 - 14:00',
        'Mittwoch' => '14:00 - 16:00',
        'Donnerstag' => '10:00 - 14:00',
        'Freitag' => '10:00 - 12:00, 14:00 - 16:00',
        'Samstag' => '12:00 - 16:00',
        'Sonntag' => '10:00 - 16:00'
      }
    end

    let(:three_records2_transformed) do
      [{
        'day_of_week' => days_to_ids(['Montag', 'Donnerstag', 'Freitag', 'Sonntag']),
        'validity' => nil,
        'time' => [{ 'opens' => '10:00', 'closes' => '12:00' }]
      }, {
        'day_of_week' => days_to_ids(['Dienstag', 'Donnerstag', 'Samstag', 'Sonntag']),
        'validity' => nil,
        'time' => [{ 'opens' => '12:00', 'closes' => '14:00' }]
      }, {
        'day_of_week' => days_to_ids(['Mittwoch', 'Freitag', 'Samstag', 'Sonntag']),
        'validity' => nil,
        'time' => [{ 'opens' => '14:00', 'closes' => '16:00' }]
      }]
    end

    let(:two_records_gapped) do
      [{
        'day_of_week' => days_to_ids(['Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag']),
        'validity' => nil,
        'time' => [{ 'opens' => '7:00', 'closes' => '12:00' }]
      }, {
        'day_of_week' => days_to_ids(['Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag']),
        'validity' => nil,
        'time' => [{ 'opens' => '13:00', 'closes' => '20:00' }]
      }]
    end

    let(:google_gapped_records) do
      {
        'Monday' => [{ 'open' => '10:00:00', 'close' => '12:00:00', 'text' => nil }, { 'open' => '14:00:00', 'close' => '18:00:00', 'text' => nil }],
        'Tuesday' => [{ 'open' => '10:00:00', 'close' => '12:00:00', 'text' => nil }, { 'open' => '14:00:00', 'close' => '18:00:00', 'text' => nil }],
        'Wednesday' => [{ 'open' => '10:00:00', 'close' => '12:00:00', 'text' => nil }, { 'open' => '14:00:00', 'close' => '18:00:00', 'text' => nil }],
        'Thursday' => [{ 'open' => '10:00:00', 'close' => '12:00:00', 'text' => nil }, { 'open' => '14:00:00', 'close' => '18:00:00', 'text' => nil }],
        'Friday' => [{ 'open' => '10:00:00', 'close' => '12:00:00', 'text' => nil }, { 'open' => '14:00:00', 'close' => '18:00:00', 'text' => nil }],
        'Saturday' => [{ 'open' => nil, 'close' => nil, 'text' => nil }],
        'Sunday' => [{ 'open' => nil, 'close' => nil, 'text' => nil }]
      }
    end

    let(:gapped_ohs) do
      [{
        'day_of_week' => days_to_ids(['Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag']),
        'validity' => nil,
        'time' => [{ 'opens' => '7:00', 'closes' => '12:00' }]
      }, {
        'day_of_week' => days_to_ids(['Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag']),
        'validity' => nil,
        'time' => [{ 'opens' => '13:00', 'closes' => '20:00' }]
      }]
    end

    let(:gapped_per_day) do
      {
        'Montag' => '7:00 - 12:00, 13:00 - 20:00',
        'Dienstag' => '7:00 - 12:00, 13:00 - 20:00',
        'Mittwoch' => '7:00 - 12:00, 13:00 - 20:00',
        'Donnerstag' => '7:00 - 12:00, 13:00 - 20:00',
        'Freitag' => '7:00 - 12:00, 13:00 - 20:00',
        'Samstag' => 'geschlossen',
        'Sonntag' => 'geschlossen'
      }
    end

    let(:next_day) do
      { 'Monday' => [{ 'open' => '20:00:00', 'close' => '02:00:00' }] }
    end

    it 'raises an exception if the wrong format is given' do
      assert_raises(NotImplementedError) { subject.new(empty_record, format: :wrong) }
    end

    it 'raises an exception if no format is given' do
      assert_raises(NotImplementedError) { subject.new(empty_record) }
    end

    it 'properly reads an empty record' do
      assert_nil(subject.new(empty_record, format: :google).to_opening_hours_specifications)
    end

    it 'reads a record for one opening_hours_specifications' do
      assert(subject.new(one_record, format: :google).to_opening_hours_specifications, one_record_transformed)
    end

    it 'reads a record with wrong_time_format' do
      assert(subject.new(one_record_wrong_time_format, format: :google, options: { wrong_time_format: true }).to_opening_hours_specifications, one_record_transformed)
    end

    it 'reads a record for two opening_hours_specifications' do
      assert(subject.new(two_records, format: :google).to_opening_hours_specifications, two_records_transformed)
    end

    it 'reads a record for three opening_hours_specifications' do
      assert(subject.new(three_records, format: :google).to_opening_hours_specifications, tree_records_transformed)
    end

    it 'converts opening_hours to a day_hash' do
      assert(subject.new(three_records, format: :google).to_per_day_opening_hours, three_records_string_output)
    end

    it 'correctly reads, converts, and simplifies three_records2' do
      opening_hours = subject.new(three_records2, format: :google)
      assert(opening_hours.to_opening_hours_specifications, three_records2_transformed)
      assert(opening_hours.to_per_day_opening_hours, three_records2_string_output)
    end

    it 'correctly imports different records formats' do
      opening_hours_g = subject.new(three_records2, format: :google)
      opening_hours_s = subject.new(three_records2_transformed, format: :opening_hours_specification)
      assert(opening_hours_g.data, opening_hours_s.data)
    end

    it 'can import converted records' do
      assert(subject.new(subject.new(three_records2, format: :google).to_opening_hours_specifications, format: :opening_hours_specification).to_per_day_opening_hours, three_records2_string_output)
    end

    it 'takes validity into account' do
      validity_hash = { 'valid_from' => '1.1.2000', 'valid_through' => '31.12.2020' }
      three_records_with_validity = tree_records_transformed.map { |item| item.merge({ 'validity' => validity_hash }) }
      assert(subject.new(three_records, format: :google, validity: validity_hash).to_opening_hours_specifications, three_records_with_validity)
    end

    it 'reads gapped_data' do
      assert(subject.new(two_records_gapped, format: :opening_hours_specification).to_per_day_opening_hours, gapped_per_day)
      assert(subject.new(two_records_gapped, format: :opening_hours_specification).to_opening_hours_specifications, gapped_ohs)
    end

    it 'hadles intervals over midnight correctly' do
      assert(subject.new(next_day, format: :google).to_per_day_opening_hours['Montag'], '20:00 - 2:00')
      assert(subject.new(next_day, format: :google).to_per_day_opening_hours['Mittwoch'], 'geschlossen')
    end
  end

  describe 'basic error handling' do
    let(:incomplete_record) do
      { 'Monday' => [{ 'open' => '10:00:00', 'close' => nil }] }
    end

    let(:incomplete_record2) do
      { 'Monday' => [{ 'open' => nil, 'close' => '10:00:00' }] }
    end

    it 'can read nil' do
      assert_nil(subject.new(nil, format: :google).to_per_day_opening_hours)
    end

    it 'can read empty_hash' do
      assert_nil(subject.new({}, format: :google).to_per_day_opening_hours)
    end

    it 'can read incomplete_record' do
      assert_nil(subject.new(incomplete_record, format: :google).to_per_day_opening_hours)
    end

    it 'can read incomplete_record2' do
      assert_nil(subject.new(incomplete_record2, format: :google).to_per_day_opening_hours)
    end

    it 'ignores hashes with irrelevant keys' do
      assert_nil(subject.new({ x: 1, y: 2 }, format: :google).to_per_day_opening_hours)
    end

    it 'handles wrong time strings' do
      ['10:00:00:00', '10 Uhr'].each do |time_string|
        wrong_time_format = incomplete_record.deep_dup
        wrong_time_format['Monday'].first['open'] = time_string
        assert_nil(subject.new(wrong_time_format, format: :google).to_per_day_opening_hours)
      end
    end
  end
end
