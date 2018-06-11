# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'

describe DataCycleCore::Generic::Feratel::TransformationFunctions do
  subject { DataCycleCore::Generic::Feratel::TransformationFunctions }

  describe 'translated text extraction' do
    let(:simple_hash) do
      {
        'Code' => {
          'text' => 'F0010'
        },
        'Names' => {
          'Translation' => {
            'Language' => 'de',
            'text' => 'All inclusive Familienhotel Burgstallerhof'
          }
        }
      }
    end

    let(:nested_hash) do
      {
        'Details' => {
          'Detail' => [simple_hash]
        },
        'Facilities' => {
          'ChangeDate' => '2012-03-13T17:25:00',
          'Facility' => [
            {
              'Id' => '2296302a-70b9-42a1-94b3-e40a3b9d0647',
              'Value' => '1'
            },
            {
              'Id' => 'be2ae5d3-a12b-4fce-87db-18cae0a7c55e',
              'Value' => '1'
            }
          ]
        }
      }
    end

    it 'extracts texts from simple hashes' do
      subject.flatten_translations(simple_hash).dig('Names', 'text').must_equal 'All inclusive Familienhotel Burgstallerhof'
      subject.flatten_translations(simple_hash).dig('Code', 'text').must_equal 'F0010'
    end

    it 'extracts texts from nested hashes' do
      subject.flatten_translations(nested_hash).dig('Details', 'Detail', 0, 'Names', 'text').must_equal 'All inclusive Familienhotel Burgstallerhof'
      subject.flatten_translations(nested_hash).dig('Details', 'Detail', 0, 'Code', 'text').must_equal 'F0010'
    end
  end

  describe 'text extraction' do
    let(:simple_hash) do
      {
        'Type' => 'Object',
        'ChangeDate' => '2017-10-19T10:17:00',
        'Id' => '10e0e144-2464-495e-99d3-3c6abaaf9ff9',
        'Company' => {
          'text' => 'All inclusive Familienhotel Burgstallerhof'
        },
        'AddressLine1' => {
          'text' => 'Dorfstraße 10'
        },
        'Country' => {
          'text' => 'AT'
        },
        'ZipCode' => {
          'text' => '9544'
        },
        'Town' => {
          'text' => 'Feld am See'
        }
      }
    end

    let(:nested_hash) do
      {
        'Addresses' => {
          'Address' => [
            simple_hash
          ]
        },
        'Facilities' => {
          'ChangeDate' => '2012-03-13T17:25:00',
          'Facility' => [
            {
              'Id' => '2296302a-70b9-42a1-94b3-e40a3b9d0647',
              'Value' => '1'
            },
            {
              'Id' => 'be2ae5d3-a12b-4fce-87db-18cae0a7c55e',
              'Value' => '1'
            }
          ]
        }
      }
    end

    it 'extracts texts from simple hashes' do
      subject.flatten_texts(simple_hash)['Company'].must_equal 'All inclusive Familienhotel Burgstallerhof'
    end

    it 'extracts texts from nested hashes' do
      subject.flatten_texts(nested_hash).dig('Addresses', 'Address', 0, 'Company').must_equal 'All inclusive Familienhotel Burgstallerhof'
    end
  end

  describe 'description extraction' do
    let(:simple_hash) do
      {
        'Descriptions' => {
          'Description' => {
            'Id' => '9988f158-a2de-4b44-9744-3246a1d63173',
            'Type' => 'ServiceProviderDescription',
            'Language' => 'de',
            'Systems' => 'L T I C',
            'ShowFrom' => '304',
            'ShowTo' => '417',
            'ChangeDate' => '2017-05-29T15:09:00',
            'text' => ' ...Beschreibungstext ...'
          }
        }
      }
    end

    let(:missing_description) do
      {
        'Descriptions' => {
          'Description' => []
        }
      }
    end

    let(:multiple_descriptions) do
      {
        'Descriptions' => {
          'Description' => [
            {
              'Id' => '9988f158-a2de-4b44-9744-3246a1d63173',
              'Type' => 'ServiceProviderDescription',
              'Language' => 'de',
              'Systems' => 'L T I C',
              'ShowFrom' => '304',
              'ShowTo' => '417',
              'ChangeDate' => '2017-05-29T15:09:00',
              'text' => '...Beschreibungstext 1 ...'
            },
            {
              'Id' => '9988f158-a2de-4b44-9744-3246a1d63173',
              'Type' => 'ServiceProviderDescription',
              'Language' => 'de',
              'Systems' => 'L T I C',
              'ShowFrom' => '304',
              'ShowTo' => '417',
              'ChangeDate' => '2017-05-29T15:09:00',
              'text' => '...Beschreibungstext 2 ...'
            }
          ]
        }
      }
    end

    let(:multiple_description_types) do
      {
        'Descriptions' => {
          'Description' => [
            {
              'Id' => '9988f158-a2de-4b44-9744-3246a1d63173',
              'Type' => 'UnkownDescription',
              'Language' => 'de',
              'Systems' => 'L T I C',
              'ShowFrom' => '304',
              'ShowTo' => '417',
              'ChangeDate' => '2017-05-29T15:09:00',
              'text' => '...Beschreibungstext 1 ...'
            },
            {
              'Id' => '9988f158-a2de-4b44-9744-3246a1d63173',
              'Type' => 'ServiceProviderDescription',
              'Language' => 'de',
              'Systems' => 'L T I C',
              'ShowFrom' => '304',
              'ShowTo' => '417',
              'ChangeDate' => '2017-05-29T15:09:00',
              'text' => '...Beschreibungstext 2 ...'
            }
          ]
        }
      }
    end

    let(:nested_description) do
      {
        'Details' => multiple_description_types
      }
    end

    it 'extracts texts from simple hashes' do
      subject.unwrap_description(simple_hash, 'ServiceProviderDescription')['ServiceProviderDescription']
        .must_equal ' ...Beschreibungstext ...'
    end

    it 'can handle missing descriptions' do
      subject.unwrap_description(missing_description, 'ServiceProviderDescription')['ServiceProviderDescription']
        .must_be_nil
    end

    it 'can handle multiple descriptions' do
      subject.unwrap_description(multiple_descriptions, 'ServiceProviderDescription')['ServiceProviderDescription']
        .must_equal '...Beschreibungstext 1 ...'
    end

    it 'can handle different description types' do
      subject.unwrap_description(multiple_description_types, 'ServiceProviderDescription')['ServiceProviderDescription']
        .must_equal '...Beschreibungstext 2 ...'
    end

    it 'extracts texts from nested hashes' do
      subject.unwrap_description(multiple_description_types, 'ServiceProviderDescription')['ServiceProviderDescription']
        .must_equal '...Beschreibungstext 2 ...'
    end
  end

  describe 'address extraction' do
    let(:simple_address) do
      {
        'Addresses' => {
          'Address' => [
            {
              'Type' => 'Object',
              'Company' => 'Company Name - Object',
              'AddressLine1' => 'Street Name'
            },
            {
              'Type' => 'Owner',
              'Company' => 'Company Name - Owner',
              'AddressLine1' => 'Street Name'
            }
          ]
        }
      }
    end

    let(:nested_hash) do
      {
        'Details' => {
          'Code' => {
            'text' => 'F0010'
          }
        }.merge(simple_address)
      }
    end

    it 'extracts address by type' do
      subject.unwrap_address(simple_address, 'Object').dig('Address', 'Company').must_equal 'Company Name - Object'
      subject.unwrap_address(simple_address, 'Owner').dig('Address', 'Company').must_equal 'Company Name - Owner'
    end

    it 'can handle missing addresses' do
      subject.unwrap_address(simple_address, 'Booking')['Address'].must_be_nil
    end

    it 'can handle missing nested hashes' do
      subject.unwrap_address(nested_hash, 'Object').dig('Details', 'Address', 'Company')
        .must_equal 'Company Name - Object'
    end
  end
end
