# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'

describe DataCycleCore::Generic::Common::OpeningHours do
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

    let(:one_record_transformed) do
      [{
        'day_of_week' => days_to_ids(['Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag']),
        'validity' => nil,
        'time' => [{
          'opens' => '10:00',
          'closes' => '22:00'
        }]
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
        'time' => [{
          'opens' => '10:00',
          'closes' => '22:00'
        }]
      }, {
        'day_of_week' => days_to_ids(['Freitag']),
        'validity' => nil,
        'time' => [{
          'opens' => '22:00',
          'closes' => '24:00'
        }]
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
        'time' => [{
          'opens' => '7:00',
          'closes' => '10:00'
        }]
      }, {
        'day_of_week' => days_to_ids(['Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag']),
        'validity' => nil,
        'time' => [{
          'opens' => '10:00',
          'closes' => '22:00'
        }]
      }, {
        'day_of_week' => days_to_ids(['Freitag']),
        'validity' => nil,
        'time' => [{
          'opens' => '22:00',
          'closes' => '24:00'
        }]
      }]
    end

    let(:tree_records_string_output) do
      {
        'Montag' => '10:00 - 22:00',
        'Dienstag' => '7:00 - 22:00',
        'Mittwoch' => '7:00 - 22:00',
        'Donnerstag' => '10:00 - 22:00',
        'Freitag' => '10:00 - 24:00',
        'Samstag' => 'geschlossen',
        'Sonntag' => 'geschlossen'
      }
    end

    it 'raises an exception if the wrong format is given' do
      assert_raises(NotImplementedError) { subject.new(empty_record, format: :wrong) }
    end

    it 'raises an exception if no format is given' do
      assert_raises(NotImplementedError) { subject.new(empty_record) }
    end

    it 'properly reads an empty record' do
      subject.new(empty_record, format: :google).to_opening_hours_specifications.must_equal []
    end

    it 'reads a record for one opening_hours_specifications' do
      subject.new(one_record, format: :google).to_opening_hours_specifications.must_equal one_record_transformed
    end

    it 'reads a record for two opening_hours_specifications' do
      subject.new(two_records, format: :google).to_opening_hours_specifications.must_equal two_records_transformed
    end

    it 'reads a record for three opening_hours_specifications' do
      subject.new(three_records, format: :google).to_opening_hours_specifications.must_equal tree_records_transformed
    end

    it 'takes validity into account' do
      validity_hash = { 'valid_from' => '1.1.2000', 'valid_through' => '31.12.2020' }
      three_records_with_validity = tree_records_transformed.map { |item| item.merge({ 'validity' => validity_hash }) }
      subject.new(three_records, format: :google, validity: validity_hash).to_opening_hours_specifications.must_equal three_records_with_validity
    end

    it 'converts opening_hours to a day_hash' do
      subject.new(three_records, format: :google).to_per_day_opening_hours.must_equal tree_records_string_output
    end
  end
end
