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
      assert_equal({ 'b' => 2 }, hash)
    end

    it 'removes namespaced keys from deep hashes' do
      hash = subject.remove_namespaced_data(hash2)
      assert_equal({ 'a' => 6, 'b' => { 'e' => 6 } }, hash)
    end

    it 'removes namespaced keys from array of hash' do
      array = subject.remove_namespaced_data(Array.wrap(hash1))
      assert_equal([{ 'b' => 2 }], array)
    end

    it 'removes namespaced_keys from array of deep_hash' do
      array = subject.remove_namespaced_data(Array.wrap(hash2))
      assert_equal([{ 'a' => 6, 'b' => { 'e' => 6 } }], array)
    end

    it 'removes all namespaced_keys from complex array of hashes' do
      array = subject.remove_namespaced_data([hash1, hash2])
      assert_equal([{ 'b' => 2 }, { 'a' => 6, 'b' => { 'e' => 6 } }], array)
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
      assert_equal({ 'a' => 1 }, hash)
    end

    it 'not removes data including stub from a hash' do
      hash = subject.remove_thing_stubs(hash2)
      assert_equal(hash2, hash)
    end

    it 'removes array of stubs from hash' do
      hash = subject.remove_thing_stubs(hash3)
      assert_equal({ 'a' => 1 }, hash)
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
      assert_equal({ 'a' => 1, '@type' => ['TouristAttraction', 'odta:PointOfInterest'] }, hash)
    end

    it 'ignores unaffected types' do
      hash = subject.type_to_onlim(hash2)
      assert_equal({ 'a' => 1, '@type' => 'POI' }, hash)
    end

    it 'adds an apropriate type in a hash with more than one type' do
      hash = subject.type_to_onlim(hash3)
      assert_equal({ 'a' => 1, '@type' => ['POI', 'TouristAttraction', 'odta:PointOfInterest'] }, hash)
    end

    it 'adds and removes types' do
      hash = subject.type_to_onlim(hash4)
      assert_equal({ 'a' => 1, '@type' => ['TouristAttraction', 'odta:PointOfInterest'] }, hash)
    end

    it 'handles subarrays correctly' do
      hash = subject.type_to_onlim(hash5)
      assert_equal(
        {
          'a' => 1,
          'b' => [
            { '@id' => '1111111', '@type' => ['POI', 'TouristAttraction', 'odta:PointOfInterest'] },
            { '@id' => '2222222', '@type' => 'POI' },
            { '@id' => '3333333', '@type' => ['TouristAttraction', 'odta:PointOfInterest'] }
          ]
        },
        hash
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
      assert_equal({ '@type' => 'POI', 'ds:compliesWith' => { '@id' => 'https://semantify.it/ds/sloejGAwT' } }, hash)
    end

    it 'does not alter unknown types' do
      hash = subject.add_complies_with({ '@type' => 'irrelevant' })
      assert_equal({ '@type' => 'irrelevant' }, hash)
    end

    it 'adds apporpriate complies_with also if for type arrays' do
      hash = subject.add_complies_with({ '@type' => ['POI', 'irrelevant'] })
      assert_equal({ '@type' => ['POI', 'irrelevant'], 'ds:compliesWith' => { '@id' => 'https://semantify.it/ds/sloejGAwT' } }, hash)
    end

    it 'also handles embedded data in subarrays' do
      hash = subject.add_complies_with(hash1)
      assert_equal(
        {
          'a' => 1,
          'b' => [
            { '@type' => ['POI', 'TouristAttraction', 'odta:PointOfInterest'], 'ds:compliesWith' => { '@id' => 'https://semantify.it/ds/sloejGAwT' } },
            { '@type' => 'POI', 'ds:compliesWith' => { '@id' => 'https://semantify.it/ds/sloejGAwT' } },
            { '@type' => ['TouristAttraction', 'odta:PointOfInterest'] }
          ]
        },
        hash
      )
    end
  end

  describe 'reject_attribute' do
    it 'rejects an simple attribue' do
      data = { a: 1, b: 2 }
      hash = subject.reject_attribute(data, :a)
      assert_equal({ b: 2 }, hash)
    end

    it 'rejects path as array and as value' do
      data = { a: 1, b: 2 }
      hash = subject.reject_attribute(data, :a)
      hash2 = subject.reject_attribute(data, [:a])
      assert_equal(hash2, hash)
    end

    it 'rejects attribute in a deep hash' do
      data = { a: 1, b: { a: 1 } }
      hash = subject.reject_attribute(data, [:b, :a])
      assert_equal({ a: 1 }, hash)
    end

    it 'rejects attribute in an array' do
      data = { a: 1, b: [{ a: 1 }, { c: 1 }] }
      hash = subject.reject_attribute(data, [:b, :a])
      assert_equal({ a: 1, b: [{ c: 1 }] }, hash)
    end

    it 'rejects attribue in an array and removes the empty array' do
      data = { a: 1, b: [{ a: 1 }, { a: 2 }] }
      hash = subject.reject_attribute(data, [:b, :a])
      assert_equal({ a: 1 }, hash)
    end

    it 'rejects also more complicated cases' do
      data = { a: 1, b: [{ a: 1 }, { a: { c: [{ d: 1 }] } }] }
      hash = subject.reject_attribute(data, [:b, :a, :c, :d])
      assert_equal({ a: 1, b: [{ a: 1 }] }, hash)
    end
  end

  describe 'select_attributes' do
    it 'selects more than one attribute' do
      data = { a: 1, b: 2, c: 3 }
      hash = subject.select_attributes(data, [:a, :b])
      assert_equal({ a: 1, b: 2 }, hash)
    end

    it 'selects single paths as array and as value' do
      data = { a: 1, b: 2, c: 3 }
      hash = subject.select_attributes(data, [:a, :b])
      hash2 = subject.select_attributes(data, [[:a], [:b]])
      assert_equal(hash2, hash)
    end

    it 'selects all attributes that start with "@"' do
      data = { a: 1, '@id' => 2 }
      hash = subject.select_attributes(data, [:b])
      assert_equal({ '@id' => 2 }, hash)
    end

    it 'selects attribute in a deep hash' do
      data = { a: 1, b: { a: 1, c: 3 } }
      hash = subject.select_attributes(data, [[:b, :a]])
      assert_equal({ b: { a: 1 } }, hash)
    end

    it 'selects attribute in an array' do
      data = { a: 1, b: [{ a: 1 }, { c: 1 }] }
      hash = subject.select_attributes(data, [[:b, :a]])
      assert_equal({ b: [{ a: 1 }] }, hash)
    end

    it 'selects attribues in an array' do
      data = { a: 1, b: [{ a: 1 }, { a: 2 }, { b: 3 }] }
      hash = subject.select_attributes(data, [[:b, :b]])
      assert_equal({ b: [{ b: 3 }] }, hash)
    end

    it 'selects deep nested attributes' do
      data = { a: 1, b: [{ a: 1 }, { a: { b: 1 } }] }
      hash = subject.select_attributes(data, [[:b, :a, :b]])
      assert_equal({ b: [{ a: { b: 1 } }] }, hash)
    end

    it 'select even more complicated cases' do
      data = { a: 1, b: [{ a: 1 }, { a: { c: [{ d: 1 }] } }] }
      hash = subject.select_attributes(data, [[:a], [:b, :a, :c, :d]])
      assert_equal({ a: 1, b: [{ a: { c: [{ d: 1 }] } }] }, hash)
    end
  end

  describe 'apply_list_type' do
    it 'does nothing if blacklist is empty' do
      data = { '@type' => 'POI', a: 1, b: 2, c: 3 }
      hash = subject.apply_list_type(data, 'POI', [], :reject_attributes)
      assert_equal(data, hash)
      hash = subject.apply_list_type(data, 'POI', nil, :reject_attributes)
      assert_equal(data, hash)
    end

    it 'does nothing if data is empy' do
      hash = subject.apply_list_type({}, 'POI', [:a], :reject_attributes)
      assert_equal({}, hash)
      hash = subject.apply_list_type(nil, 'POI', [:a], :reject_attributes)
      assert(hash.nil?)
    end

    it 'blacklists attributes from a given datatype' do
      data = { '@type' => 'POI', a: 1, b: 2, c: 3 }
      hash = subject.apply_list_type(data, 'POI', [:a, :b], :reject_attributes)
      assert_equal({ '@type' => 'POI', c: 3 }, hash)
    end

    it 'ignores other types' do
      data = { '@type' => 'POI', a: 1, b: 2, c: 3 }
      hash = subject.apply_list_type(data, 'X', [:a, :b], :reject_attributes)
      assert_equal(data, hash)
    end

    it 'blacklists data from nested datastructure' do
      data = { a: 1, b: [{ '@type' => 'POI', a: 1, b: 2, c: 3 }] }
      hash = subject.apply_list_type(data, 'POI', [:a, :b], :reject_attributes)
      assert_equal({ a: 1, b: [{ '@type' => 'POI', c: 3 }] }, hash)
    end

    it 'blacklists attributes in all occurrences from a given datatype' do
      poi_data = { '@type' => 'POI', a: 1, b: 2, c: 3 }
      data = { a: 1, b: [poi_data.deep_dup], c: poi_data.deep_dup }
      hash = subject.apply_list_type(data, 'POI', [:a, :b], :reject_attributes)
      assert_equal({ a: 1, b: [{ '@type' => 'POI', c: 3 }], c: { '@type' => 'POI', c: 3 } }, hash)
    end

    it 'does nothing if blacklist is empty' do
      data = { '@type' => 'POI', a: 1, b: 2, c: 3 }
      hash = subject.apply_list_type(data, 'POI', [], :select_attributes)
      assert_equal(data, hash)
      hash = subject.apply_list_type(data, 'POI', nil, :select_attributes)
      assert_equal(data, hash)
    end

    it 'does nothing if data is empy' do
      hash = subject.apply_list_type({}, 'POI', [:a], :select_attributes)
      assert_equal({}, hash)
      hash = subject.apply_list_type(nil, 'POI', [:a], :select_attributes)
      assert(hash.nil?)
    end

    it 'whitelist attributes from a given datatype' do
      data = { '@type' => 'POI', a: 1, b: 2, c: 3 }
      hash = subject.apply_list_type(data, 'POI', [:a, :b], :select_attributes)
      assert_equal({ '@type' => 'POI', a: 1, b: 2 }, hash)
    end

    it 'ignores other types' do
      data = { '@type' => 'POI', a: 1, b: 2, c: 3 }
      hash = subject.apply_list_type(data, 'X', [:a, :b], :select_attributes)
      assert_equal(data, hash)
    end

    it 'whitelists data from nested datastructure' do
      data = { a: 1, b: [{ '@type' => 'POI', a: 1, b: 2, c: 3 }] }
      hash = subject.apply_list_type(data, 'POI', [:a, :b], :select_attributes)
      assert_equal({ a: 1, b: [{ '@type' => 'POI', a: 1, b: 2 }] }, hash)
    end

    it 'whitelists attributes in all occurrences from a given datatype' do
      poi_data = { '@type' => 'POI', a: 1, b: 2, c: 3 }
      data = { a: 1, b: [poi_data.deep_dup], c: poi_data.deep_dup }
      hash = subject.apply_list_type(data, 'POI', [:a, :b], :select_attributes)
      assert_equal({ a: 1, b: [{ '@type' => 'POI', a: 1, b: 2 }], c: { '@type' => 'POI', a: 1, b: 2 } }, hash)
    end
  end

  describe 'apply_blacklist' do
    let(:data_hash) do
      {
        '@context' => [
          'https://schema.org/',
          {
            '@base' => 'http://localhost:3000/api/v4/universal/',
            'skos' => 'https://www.w3.org/2009/08/skos-reference/skos.html#',
            'dct' => 'http://purl.org/dc/terms/',
            'cc' => 'http://creativecommons.org/ns#',
            'dc' => 'https://schema.datacycle.at/',
            'dcls' => 'http://localhost:3000/schema/',
            'odta' => 'https://odta.io/voc/'
          }
        ],
        '@graph' => [{
          '@id' => '11111111-1111-1111-1111-111111111111',
          '@type' => ['Place', 'TouristAttraction', 'dcls:POI'],
          'name' => [{ '@language' => 'de', '@value' => 'name' }],
          'description' => [{ '@language' => 'de', '@value' => 'description' }],
          'address' => {
            '@id' => '11111111-1111-1111-1111-222222222222',
            '@type' => 'PostalAddress',
            'streetAddress' => 'Straße 40',
            'postalCode' => '12345',
            'addressLocality' => 'Stadt',
            'addressCountry' => 'DE',
            'telephone' => [{ '@language' => 'de', '@value' => '(0049)1111 111111' }],
            'faxNumber' => [{ '@language' => 'de', '@value' => '(0049)2222 222222' }],
            'email' => [{ '@language' => 'de', '@value' => 'maikammer@maikammer-erlebnisland.de' }],
            'url' => [{ '@language' => 'de', '@value' => 'https://www.maikammer.de' }]
          },
          'geo' => {
            '@id' => '76112d34-6f6f-4d37-8e45-679147a4c5af',
            '@type' => 'GeoCoordinates',
            'longitude' => 8.0,
            'latitude' => 49.0,
            'unwanted' => 1,
            'unwanted1' => {
              'unwanted_1' => 1,
              'unwanted_2' => 2
            },
            'more_data' => {
              'unwanted' => 1,
              'keep' => 2
            }
          }
        }]
      }
    end

    let(:blacklist) do
      {
        'GeoCoordinates' => ['unwanted', 'unwanted1', ['more_data', 'unwanted']],
        'PostalAddress' => ['telephone', 'faxNumber', 'email', 'url'],
        'Place' => ['description']
      }
    end

    let(:cleaned_hash) do
      {
        '@context' => [
          'https://schema.org/',
          {
            '@base' => 'http://localhost:3000/api/v4/universal/',
            'skos' => 'https://www.w3.org/2009/08/skos-reference/skos.html#',
            'dct' => 'http://purl.org/dc/terms/',
            'cc' => 'http://creativecommons.org/ns#',
            'dc' => 'https://schema.datacycle.at/',
            'dcls' => 'http://localhost:3000/schema/',
            'odta' => 'https://odta.io/voc/'
          }
        ],
        '@graph' => [{
          '@id' => '11111111-1111-1111-1111-111111111111',
          '@type' => ['Place', 'TouristAttraction', 'dcls:POI'],
          'name' => [{ '@language' => 'de', '@value' => 'name' }],
          'address' => {
            '@id' => '11111111-1111-1111-1111-222222222222',
            '@type' => 'PostalAddress',
            'streetAddress' => 'Straße 40',
            'postalCode' => '12345',
            'addressLocality' => 'Stadt',
            'addressCountry' => 'DE'
          },
          'geo' => {
            '@id' => '76112d34-6f6f-4d37-8e45-679147a4c5af',
            '@type' => 'GeoCoordinates',
            'longitude' => 8.0,
            'latitude' => 49.0,
            'more_data' => {
              'keep' => 2
            }
          }
        }]
      }
    end

    it 'apply a blackist to a api/v4 graph' do
      hash = subject.apply_blacklist(data_hash, blacklist)
      assert_equal(cleaned_hash, hash)
    end
  end

  describe 'apply_whitelist' do
    let(:data_hash) do
      {
        '@context' => [
          'https://schema.org/',
          {
            '@base' => 'http://localhost:3000/api/v4/universal/',
            'skos' => 'https://www.w3.org/2009/08/skos-reference/skos.html#',
            'dct' => 'http://purl.org/dc/terms/',
            'cc' => 'http://creativecommons.org/ns#',
            'dc' => 'https://schema.datacycle.at/',
            'dcls' => 'http://localhost:3000/schema/',
            'odta' => 'https://odta.io/voc/'
          }
        ],
        '@graph' => [{
          '@id' => '11111111-1111-1111-1111-111111111111',
          '@type' => ['Place', 'TouristAttraction', 'dcls:POI'],
          'name' => [{ '@language' => 'de', '@value' => 'name' }],
          'description' => [{ '@language' => 'de', '@value' => 'description' }],
          'address' => {
            '@id' => '11111111-1111-1111-1111-222222222222',
            '@type' => 'PostalAddress',
            'streetAddress' => 'Straße 40',
            'postalCode' => '12345',
            'addressLocality' => 'Stadt',
            'addressCountry' => 'DE',
            'telephone' => [{ '@language' => 'de', '@value' => '(0049)1111 111111' }],
            'faxNumber' => [{ '@language' => 'de', '@value' => '(0049)2222 222222' }],
            'email' => [{ '@language' => 'de', '@value' => 'maikammer@maikammer-erlebnisland.de' }],
            'url' => [{ '@language' => 'de', '@value' => 'https://www.maikammer.de' }]
          },
          'geo' => {
            '@id' => '76112d34-6f6f-4d37-8e45-679147a4c5af',
            '@type' => 'GeoCoordinates',
            'longitude' => 8.0,
            'latitude' => 49.0,
            'unwanted' => 1,
            'unwanted1' => {
              'unwanted_1' => 1,
              'unwanted_2' => 2
            },
            'more_data' => {
              'unwanted' => 1,
              'keep' => 2
            }
          }
        }]
      }
    end

    let(:whitelist) do
      {
        'GeoCoordinates' => ['longitude', 'latitude', ['more_data', 'keep']],
        'PostalAddress' => ['streetAddress', 'postalCode', 'addressLocality', 'addressCountry'],
        'Place' => ['name', 'description', 'address', 'geo']
      }
    end

    let(:cleaned_hash) do
      {
        '@context' => [
          'https://schema.org/',
          {
            '@base' => 'http://localhost:3000/api/v4/universal/',
            'skos' => 'https://www.w3.org/2009/08/skos-reference/skos.html#',
            'dct' => 'http://purl.org/dc/terms/',
            'cc' => 'http://creativecommons.org/ns#',
            'dc' => 'https://schema.datacycle.at/',
            'dcls' => 'http://localhost:3000/schema/',
            'odta' => 'https://odta.io/voc/'
          }
        ],
        '@graph' => [{
          '@id' => '11111111-1111-1111-1111-111111111111',
          '@type' => ['Place', 'TouristAttraction', 'dcls:POI'],
          'name' => [{ '@language' => 'de', '@value' => 'name' }],
          'description' => [{ '@language' => 'de', '@value' => 'description' }],
          'address' => {
            '@id' => '11111111-1111-1111-1111-222222222222',
            '@type' => 'PostalAddress',
            'streetAddress' => 'Straße 40',
            'postalCode' => '12345',
            'addressLocality' => 'Stadt',
            'addressCountry' => 'DE'
          },
          'geo' => {
            '@id' => '76112d34-6f6f-4d37-8e45-679147a4c5af',
            '@type' => 'GeoCoordinates',
            'longitude' => 8.0,
            'latitude' => 49.0,
            'more_data' => {
              'keep' => 2
            }
          }
        }]
      }
    end

    it 'apply a blackist to a api/v4 graph' do
      hash = subject.apply_whitelist(data_hash, whitelist)
      assert_equal(cleaned_hash, hash)
    end
  end
end
