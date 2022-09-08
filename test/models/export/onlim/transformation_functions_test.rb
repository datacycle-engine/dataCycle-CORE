# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'

describe DataCycleCore::Export::Onlim::TransformationFunctions do
  subject do
    DataCycleCore::Export::Onlim::TransformationFunctions
  end

  describe 'remove_namespaced_data' do
    let(:hash1) do
      {
        'a:x' => 1,
        'b' => 2
      }
    end

    let(:hash2) do
      {
        'a' => 6,
        'b' => {
          'd:x' => 6,
          'e' => 6
        },
        'c' => {
          'd:x' => 6
        }
      }
    end

    it 'removes namespaced keys from a hash' do
      hash = subject.remove_namespaced_data(hash1)
      assert(hash == { 'b' => 2 })
    end

    it 'removes namespaced keys from deep hashes' do
      hash = subject.remove_namespaced_data(hash2)
      assert(hash == { 'a' => 6, 'b' => { 'e' => 6 } })
    end

    it 'removes namespaced keys from array of hash' do
      array = subject.remove_namespaced_data(Array.wrap(hash1))
      assert(array == [{ 'b' => 2 }])
    end

    it 'removes namespaced_keys from array of deep_hash' do
      array = subject.remove_namespaced_data(Array.wrap(hash2))
      assert(array == [{ 'a' => 6, 'b' => { 'e' => 6 } }])
    end

    it 'removes all namespaced_keys from complex array of hashes' do
      array = subject.remove_namespaced_data([hash1, hash2])
      assert(array == [{ 'b' => 2 }, { 'a' => 6, 'b' => { 'e' => 6 } }])
    end
  end

  describe 'remove_thing_stubs' do
    let(:hash1) do
      {
        'a' => 1,
        'b' => { '@id' => '1111111', '@type' => 'POI' }
      }
    end

    let(:hash2) do
      {
        'a' => 1,
        'b' => { '@id' => '1111111', '@type' => 'POI', 'name' => 'test' }
      }
    end

    let(:hash3) do
      {
        'a' => 1,
        'b' => [
          { '@id' => '1111111', '@type' => 'POI' },
          { '@id' => '2222222', '@type' => 'POI' },
          { '@id' => '3333333', '@type' => 'POI' }
        ]
      }
    end

    it 'removes stub from a hash' do
      hash = subject.remove_thing_stubs(hash1)
      assert(hash == { 'a' => 1 })
    end

    it 'not removes data including stub from a hash' do
      hash = subject.remove_thing_stubs(hash2)
      assert(hash == hash2)
    end

    it 'removes array of stubs from hash' do
      hash = subject.remove_thing_stubs(hash3)
      assert(hash == { 'a' => 1 })
    end
  end

  describe 'type_to_onlim' do
    let(:hash1) do
      {
        'a' => 1,
        '@type' => 'TouristAttraction'
      }
    end

    let(:hash2) do
      {
        'a' => 1,
        '@type' => 'POI'
      }
    end

    let(:hash3) do
      {
        'a' => 1,
        '@type' => ['POI', 'TouristAttraction']
      }
    end

    let(:hash4) do
      {
        'a' => 1,
        '@type' => ['dcls:whatever', 'TouristAttraction']
      }
    end

    let(:hash5) do
      {
        'a' => 1,
        'b' => [
          { '@id' => '1111111', '@type' => ['POI', 'TouristAttraction'] },
          { '@id' => '2222222', '@type' => 'POI' },
          { '@id' => '3333333', '@type' => 'TouristAttraction' }
        ]
      }
    end

    it 'adds an apropriate type in a hash' do
      hash = subject.type_to_onlim(hash1)
      assert(hash == { 'a' => 1, '@type' => ['TouristAttraction', 'odta:PointOfInterest'] })
    end

    it 'ignores unaffected types' do
      hash = subject.type_to_onlim(hash2)
      assert(hash == { 'a' => 1, '@type' => 'POI' })
    end

    it 'adds an apropriate type in a hash with more than one type' do
      hash = subject.type_to_onlim(hash3)
      assert(hash == { 'a' => 1, '@type' => ['POI', 'TouristAttraction', 'odta:PointOfInterest'] })
    end

    it 'adds and removes types' do
      hash = subject.type_to_onlim(hash4)
      assert(hash == { 'a' => 1, '@type' => ['TouristAttraction', 'odta:PointOfInterest'] })
    end

    it 'handles subarrays correctly' do
      hash = subject.type_to_onlim(hash5)
      assert(
        hash ==
        {
          'a' => 1,
          'b' => [
            { '@id' => '1111111', '@type' => ['POI', 'TouristAttraction', 'odta:PointOfInterest'] },
            { '@id' => '2222222', '@type' => 'POI' },
            { '@id' => '3333333', '@type' => ['TouristAttraction', 'odta:PointOfInterest'] }
          ]
        }
      )
    end
  end

  describe 'add_complies_with' do
    let(:hash1) do
      {
        'a' => 1,
        'b' => [
          { '@type' => ['POI', 'TouristAttraction', 'odta:PointOfInterest'] },
          { '@type' => 'POI' },
          { '@type' => ['TouristAttraction', 'odta:PointOfInterest'] }
        ]
      }
    end

    it 'adds apporpriate complies_with' do
      hash = subject.add_complies_with({ '@type' => 'POI' })
      assert(hash == { '@type' => 'POI', 'ds:compliesWith' => { '@id' => 'https://semantify.it/ds/sloejGAwT' } })
    end

    it 'does not alter unknown types' do
      hash = subject.add_complies_with({ '@type' => 'irrelevant' })
      assert(hash == { '@type' => 'irrelevant' })
    end

    it 'adds apporpriate complies_with also if for type arrays' do
      hash = subject.add_complies_with({ '@type' => ['POI', 'irrelevant'] })
      assert(hash == { '@type' => ['POI', 'irrelevant'], 'ds:compliesWith' => { '@id' => 'https://semantify.it/ds/sloejGAwT' } })
    end

    it 'also handles embedded data in subarrays' do
      hash = subject.add_complies_with(hash1)
      assert(
        hash ==
        {
          'a' => 1,
          'b' => [
            { '@type' => ['POI', 'TouristAttraction', 'odta:PointOfInterest'], 'ds:compliesWith' => { '@id' => 'https://semantify.it/ds/sloejGAwT' } },
            { '@type' => 'POI', 'ds:compliesWith' => { '@id' => 'https://semantify.it/ds/sloejGAwT' } },
            { '@type' => ['TouristAttraction', 'odta:PointOfInterest'] }
          ]
        }
      )
    end
  end
end
