# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'
require 'helpers/minitest_spec_helper'

describe DataCycleCore::MasterData::NormalizeData do
  include DataCycleCore::MinitestSpecHelper

  subject do
    DataCycleCore::MasterData::NormalizeData
  end

  describe 'hash_helper' do
    let(:hash1) do
      {
        'a' => 1,
        'b' => 2,
        'c' => {
          'd' => 4,
          'e' => {
            'f' => 'hallo'
          }
        }
      }
    end

    let(:hash2) do
      {
        'a' => 6,
        'b' => 6,
        'c' => {
          'd' => 6,
          'e' => {
            'f' => 6
          }
        },
        'x' => {
          'y' => {
            'z' => 6
          }
        }
      }
    end

    it 'updates a value deep in the data_hash' do
      hash = subject.update_path(hash1, 'a', 6)
      assert(hash.dig('a'), 6)
      hash = subject.update_path(hash1, 'c/d', 6)
      assert(hash.dig('c', 'd'), 6)
      hash = subject.update_path(hash1, 'c/e/f', 6)
      assert(hash.dig('c', 'e', 'f'), 6)
    end

    it 'ignores updates if trying to update a subhash' do
      hash = subject.update_path(hash1, 'a/c', 6)
      assert(hash.dig('a'), 1)
    end

    it 'inserts leaf if path does not previously exist' do
      hash = subject.update_path(hash1, 'x/y/z', 6)
      assert(hash.dig('x', 'y', 'z'), 6)
    end

    it 'updates values from an update_list' do
      update_list = [
        { 'id' => 'a', 'content' => 6 },
        { 'id' => 'b', 'content' => 6 },
        { 'id' => 'c/d', 'content' => 6 },
        { 'id' => 'c/e/f', 'content' => 6 },
        { 'id' => 'x/y/z', 'content' => 6 }
      ]
      hash = subject.update_data(hash1, update_list)
      assert(hash, hash2)
      hash_new = subject.update_data({}, update_list)
      assert(hash_new, hash2)
    end
  end

  describe 'normalize_data' do
    let(:person_template) do
      {
        'name' => 'Person',
        'type' => 'object',
        'schema_ancestors' => ['Person'],
        'content_type' => 'entity',
        'properties' => {
          'id' => { 'type' => 'key', 'label' => 'id' },
          'image' => { 'type' => 'linked', 'label' => 'Bilder', 'template_name' => 'Bild' },
          'honorific_prefix' => { 'type' => 'string', 'label' => 'Anrede / Titel', 'storage_location' => 'translated_value' },
          'given_name' => { 'type' => 'string', 'label' => 'Vorname', 'normalize' => { 'id' => 'forename', 'type' => 'forename' }, 'storage_location' => 'column' },
          'family_name' => { 'type' => 'string', 'label' => 'Nachname', 'normalize' => { 'id' => 'surname', 'type' => 'surname' }, 'storage_location' => 'column' },
          'gender' => { 'type' => 'classification', 'label' => 'Geschlecht', 'tree_label' => 'Geschlecht' },
          'job_title' => { 'type' => 'string', 'label' => 'Position', 'storage_location' => 'translated_value' },
          'address' => {
            'type' => 'object',
            'label' => 'Adresse',
            'storage_location' => 'value',
            'properties' => {
              'postal_code' => { 'type' => 'string', 'label' => 'PLZ', 'normalize' => { 'id' => 'zip', 'type' => 'zip' }, 'storage_location' => 'value' },
              'street_address' => { 'type' => 'string', 'label' => 'Straße', 'normalize' => { 'id' => 'street', 'type' => 'street' }, 'storage_location' => 'value' },
              'address_country' => { 'type' => 'string', 'label' => 'Land', 'normalize' => { 'id' => 'country', 'type' => 'country' }, 'storage_location' => 'value' },
              'address_locality' => { 'type' => 'string', 'label' => 'Ort', 'normalize' => { 'id' => 'city', 'type' => 'city' }, 'storage_location' => 'value' }
            }
          },
          'data_type' => { 'type' => 'classification', 'label' => 'Inhaltstype', 'tree_label' => 'Inhaltstypen', 'default_value' => 'Person' },
          'description' => { 'type' => 'string', 'label' => 'Text', 'storage_location' => 'column' },
          'contact_info' => {
            'type' => 'object',
            'label' => 'Kontakt',
            'storage_location' => 'translated_value',
            'properties' => {
              'url' => { 'type' => 'string', 'label' => 'Web', 'storage_location' => 'translated_value' },
              'email' => { 'type' => 'string', 'label' => 'E-Mail', 'normalize' => { 'id' => 'email', 'type' => 'email' }, 'storage_location' => 'translated_value' },
              'telephone' => { 'type' => 'string', 'label' => 'Telefonnummer', 'storage_location' => 'translated_value' },
              'fax_number' => { 'type' => 'string', 'label' => 'Fax', 'storage_location' => 'translated_value' }
            }
          },
          'date_created' => { 'type' => 'datetime', 'label' => 'Erstellungsdatum', 'storage_location' => 'value' },
          'date_deleted' => { 'type' => 'datetime', 'label' => 'Gelöschtdatum', 'storage_location' => 'value' },
          'date_modified' => { 'type' => 'datetime', 'label' => 'Änderungsdatum', 'storage_location' => 'value' }
        }
      }
    end

    let(:data_hash) do
      {
        'data1' => 'test1',
        'data2' => 'test2',
        'data3' => {
          'data4' => 'test4'
        },
        'given_name' => 'Martin',
        'family_name' => 'Oehzelt',
        'address' => {
          'postal_code' => '',
          'street_address' => 'Ossiacher Zeile 30',
          'address_country' => 'Österreich',
          'address_locality' => 'Villach'
        },
        'contact_info' => {
          'url' => 'http://test.at',
          'email' => 'oehzelt@test.at'
        }
      }
    end

    let(:normalizable_hash) do
      [
        { 'data_hash_path' => 'given_name',               'id' => 'FORENAME', 'type' => 'FORENAME', 'content' => 'Martin'             },
        { 'data_hash_path' => 'family_name',              'id' => 'SURNAME',  'type' => 'SURNAME',  'content' => 'Oehzelt'            },
        { 'data_hash_path' => 'address/postal_code',      'id' => 'ZIP',      'type' => 'ZIP',      'content' => ''                   },
        { 'data_hash_path' => 'address/street_address',   'id' => 'STREET',   'type' => 'STREET',   'content' => 'Ossiacher Zeile 30' },
        { 'data_hash_path' => 'address/address_country',  'id' => 'COUNTRY',  'type' => 'COUNTRY',  'content' => 'Österreich'         },
        { 'data_hash_path' => 'address/address_locality', 'id' => 'CITY',     'type' => 'CITY',     'content' => 'Villach'            },
        { 'data_hash_path' => 'contact_info/email',       'id' => 'EMAIL',    'type' => 'EMAIL',    'content' => 'oehzelt@test.at'    }
      ]
    end

    let(:transformation_hash) do
      [
        { 'data_hash_path' => 'given_name',               'id' => 'FORENAME', 'type' => 'FORENAME' },
        { 'data_hash_path' => 'family_name',              'id' => 'SURNAME',  'type' => 'SURNAME'  },
        { 'data_hash_path' => 'address/postal_code',      'id' => 'ZIP',      'type' => 'ZIP'      },
        { 'data_hash_path' => 'address/street_address',   'id' => 'STREET',   'type' => 'STREET'   },
        { 'data_hash_path' => 'address/address_country',  'id' => 'COUNTRY',  'type' => 'COUNTRY'  },
        { 'data_hash_path' => 'address/address_locality', 'id' => 'CITY',     'type' => 'CITY'     },
        { 'data_hash_path' => 'contact_info/email',       'id' => 'EMAIL',    'type' => 'EMAIL'    }
      ]
    end

    let(:normalizable_data) do
      [
        { 'id' => 'FORENAME', 'type' => 'FORENAME', 'content' => 'Martin'             },
        { 'id' => 'SURNAME',  'type' => 'SURNAME',  'content' => 'Oehzelt'            },
        { 'id' => 'ZIP',      'type' => 'ZIP',      'content' => ''                   },
        { 'id' => 'STREET',   'type' => 'STREET',   'content' => 'Ossiacher Zeile 30' },
        { 'id' => 'COUNTRY',  'type' => 'COUNTRY',  'content' => 'Österreich'         },
        { 'id' => 'CITY',     'type' => 'CITY',     'content' => 'Villach'            },
        { 'id' => 'EMAIL',    'type' => 'EMAIL',    'content' => 'oehzelt@test.at'    }
      ]
    end

    let(:normalize_report) do
      {
        'id' => 307,
        'status' => 'OK',
        'actionList' => [
          {
            'entryId' => '123xyz',
            'fieldsBefore' => [{ 'id' => 'ZIP', 'type' => 'ZIP', 'content' => '' }],
            'fieldsAfter' => [],
            'fieldsProposed' => [],
            'taskType' => 'DELETE',
            'taskId' => 'Cleanup_ALL_RemoveNullOrEmpty',
            'taskPhase' => 'CLEANUP'
          },
          {
            'entryId' => '123xyz',
            'fieldsBefore' => [{ 'id' => 'STREET', 'type' => 'STREET', 'content' => 'Ossiacher Zeile 30' }],
            'fieldsAfter' => [
              { 'id' => 'STREET', 'type' => 'STREET', 'content' => 'Ossiacher Zeile' },
              { 'id' => 'STREETNR', 'type' => 'STREETNR', 'content' => '30' }
            ],
            'fieldsProposed' => [],
            'taskType' => 'SPLIT',
            'taskId' => 'Split_StreetStreetnr',
            'taskPhase' => 'RESTRUCTURE'
          },
          {
            'entryId' => '123xyz',
            'fieldsBefore' => [],
            'fieldsAfter' => [],
            'fieldsProposed' => [
              { 'id' => 'ZIP', 'type' => 'ZIP', 'content' => '9504' },
              { 'id' => 'ZIP', 'type' => 'ZIP', 'content' => '9585' },
              { 'id' => 'ZIP', 'type' => 'ZIP', 'content' => '9524' },
              { 'id' => 'ZIP', 'type' => 'ZIP', 'content' => '9500' }
            ],
            'taskType' => 'PROPOSE',
            'taskId' => 'Correction_CountryCityZip',
            'taskPhase' => 'CORRECT'
          },
          {
            'entryId' => '123xyz',
            'fieldsBefore' => [{ 'id' => 'COUNTRY', 'type' => 'COUNTRY', 'content' => 'Österreich' }],
            'fieldsAfter' => [{ 'id' => 'COUNTRY', 'type' => 'COUNTRY', 'content' => 'AT' }],
            'fieldsProposed' => [],
            'taskType' => 'ALTER',
            'taskId' => 'Norm_Country',
            'taskPhase' => 'NORM'
          },
          {
            'entryId' => '123xyz',
            'fieldsBefore' => [],
            'fieldsAfter' => [{ 'id' => 'SEX', 'type' => 'SEX', 'content' => 'M' }],
            'fieldsProposed' => [],
            'taskType' => 'ADD',
            'taskId' => 'Correction_SexForename',
            'taskPhase' => 'CORRECT'
          },
          {
            'entryId' => '123xyz',
            'fieldsBefore' => [],
            'fieldsAfter' => [],
            'fieldsProposed' => [],
            'taskType' => 'ERROR',
            'taskId' => 'Check_CountryZipCityStreet',
            'taskPhase' => 'VALIDATE',
            'message' => 'Unknown or Invalid address COUNTRY+ZIP+CITY+STREET'
          }
        ],
        'entry' => {
          'comment' => 'API Test',
          'fields' => [
            { 'id' => 'STREET',   'type' => 'STREET',   'content' => 'Ossiacher Zeile' },
            { 'id' => 'COUNTRY',  'type' => 'COUNTRY',  'content' => 'AT' },
            { 'id' => 'CITY',     'type' => 'CITY',     'content' => 'Villach' },
            { 'id' => 'FORENAME', 'type' => 'FORENAME', 'content' => 'Martin' },
            { 'id' => 'SURNAME',  'type' => 'SURNAME',  'content' => 'Oehzelt' },
            { 'id' => 'EMAIL',    'type' => 'EMAIL',    'content' => 'oehzelt@test.at' },
            { 'id' => 'STREETNR', 'type' => 'STREETNR', 'content' => '30' },
            { 'id' => 'SEX',      'type' => 'SEX',      'content' => 'M' }
          ],
          'id' => '123xyz'
        }
      }
    end

    let(:normalized_data) do
      [
        { 'id' => 'STREET',   'type' => 'STREET',   'content' => 'Ossiacher Zeile'  },
        { 'id' => 'COUNTRY',  'type' => 'COUNTRY',  'content' => 'AT'               },
        { 'id' => 'CITY',     'type' => 'CITY',     'content' => 'Villach'          },
        { 'id' => 'FORENAME', 'type' => 'FORENAME', 'content' => 'Martin'           },
        { 'id' => 'SURNAME',  'type' => 'SURNAME',  'content' => 'Oehzelt'          },
        { 'id' => 'EMAIL',    'type' => 'EMAIL',    'content' => 'oehzelt@test.at'  },
        { 'id' => 'STREETNR', 'type' => 'STREETNR', 'content' => '30'               },
        { 'id' => 'SEX',      'type' => 'SEX',      'content' => 'M'                }
      ]
    end

    let(:merged_fields) do
      [
        { 'id' => 'STREET',   'type' => 'STREET',   'content' => 'Ossiacher Zeile 30' },
        { 'id' => 'COUNTRY',  'type' => 'COUNTRY',  'content' => 'AT'                 },
        { 'id' => 'CITY',     'type' => 'CITY',     'content' => 'Villach'            },
        { 'id' => 'FORENAME', 'type' => 'FORENAME', 'content' => 'Martin'             },
        { 'id' => 'SURNAME',  'type' => 'SURNAME',  'content' => 'Oehzelt'            },
        { 'id' => 'EMAIL',    'type' => 'EMAIL',    'content' => 'oehzelt@test.at'    },
        { 'id' => 'SEX',      'type' => 'SEX',      'content' => 'M'                  }
      ]
    end

    let(:back_transformed_data) do
      [
        { 'id' => 'address/street_address', 'type' => 'STREET', 'content' => 'Ossiacher Zeile 30' },
        { 'id' => 'address/address_country', 'type' => 'COUNTRY', 'content' => 'AT' },
        { 'id' => 'address/address_locality', 'type' => 'CITY', 'content' => 'Villach' },
        { 'id' => 'given_name', 'type' => 'FORENAME', 'content' => 'Martin' },
        { 'id' => 'family_name', 'type' => 'SURNAME', 'content' => 'Oehzelt' },
        { 'id' => 'contact_info/email', 'type' => 'EMAIL', 'content' => 'oehzelt@test.at' },
        { 'id' => nil, 'type' => 'SEX', 'content' => 'M' }
      ]
    end

    let(:diff_hash) do
      {
        'address' => {
          'postal_code' => ['?', ['9504', '9585', '9524', '9500']],
          'address_country' => ['~', 'AT', 'Österreich']
        },
        'SEX' => ['+', 'M'],
        'ERROR' => ['!', 'Unknown or Invalid address COUNTRY+ZIP+CITY+STREET']
      }
    end

    let(:returned_data) do
      {
        'data1' => 'test1',
        'data2' => 'test2',
        'data3' => {
          'data4' => 'test4'
        },
        'given_name' => 'Martin',
        'family_name' => 'Oehzelt',
        'address' => {
          'postal_code' => '',
          'street_address' => 'Ossiacher Zeile 30',
          'address_country' => 'AT',
          'address_locality' => 'Villach'
        },
        'contact_info' => {
          'url' => 'http://test.at',
          'email' => 'oehzelt@test.at'
        }
      }
    end

    it 'grabs correctly all normalizable data attributs' do
      assert(subject.normalizable_data(nil, person_template.dig('properties'), data_hash), normalizable_hash)
    end

    it 'does the preprocessing of the data correctly' do
      norm_hash, transformation = subject.preprocess_data(person_template, data_hash)
      assert(norm_hash, normalizable_data)
      assert(transformation, transformation_hash)
    end

    it 'merges correctly street and street_nr' do
      merged_report = subject.merge_street_streetnr(normalize_report)
      assert(merged_report.dig('entry', 'fields'), merged_fields)
      new_action_list = normalize_report.dig('actionList').deep_dup
      assert(merged_report.dig('actionList'), new_action_list)
    end

    it 'back_transforms normalized_data to original ids and schema' do
      back_trans = subject.back_transform(merged_fields, transformation_hash)
      assert(back_trans, back_transformed_data)
    end

    it 'correctly updates data according to normalized action_list' do
      assert(subject.update_data(data_hash, back_transformed_data), returned_data)
    end

    it 'does post_processing correctly' do
      updated_data, diffs = subject.postprocess_data(data_hash, transformation_hash, normalize_report, person_template)
      assert(diffs, diff_hash)
      assert(updated_data, returned_data)
    end

    it 'does the whole normalization correctly' do
      logger = DataCycleCore::Generic::Logger::LogFile.new('normalize')
      updated_data, diffs = subject.new(logger: logger).normalize(data_hash, person_template)
      assert(diffs, diff_hash.except('ERROR'))
      assert(updated_data, returned_data)
    end

    it 'returns original data and a empty hash if no template, or no data a given' do
      logger = DataCycleCore::Generic::Logger::LogFile.new('normalize')

      updated_data, diffs = subject.new(logger: logger).normalize(data_hash, nil)
      assert(diffs == {})
      assert(updated_data, data_hash)

      updated_data, diffs = subject.new(logger: logger).normalize(nil, person_template)
      assert(diffs == {})
      assert(updated_data.nil?)

      updated_data, diffs = subject.new(logger: logger).normalize(nil, nil)
      assert(diffs == {})
      assert(updated_data.nil?)
    end
  end
end
