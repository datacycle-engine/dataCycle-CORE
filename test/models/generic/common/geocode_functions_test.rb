# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'
require 'helpers/minitest_spec_helper'

describe DataCycleCore::Generic::Common::Transformations::GeocodeFunctions do
  include DataCycleCore::MinitestSpecHelper

  subject { DataCycleCore::Generic::Common::Transformations::GeocodeFunctions }

  let(:point) { RGeo::Geographic.spherical_factory(srid: 4326).point(11.0, 46.0) }
  let(:address) { { 'postal_code' => '1010', 'street_address' => 'Main 1', 'address_locality' => 'Wien' } }

  # self-returning stand-in for Concept.for_tree(...).with_internal_name(...).pluck(...)
  def concept_chain
    chain = Object.new
    chain.define_singleton_method(:with_internal_name) { |_| chain }
    chain.define_singleton_method(:pluck) { |_| ['cid-1'] }
    chain
  end

  def geocode_feature(geocode_result: nil, reverse_result: nil, reverse_enabled: true)
    feature = Object.new
    feature.define_singleton_method(:enabled?) { true }
    feature.define_singleton_method(:geocode_address) { |_| geocode_result }
    feature.define_singleton_method(:reverse_geocode_enabled?) { reverse_enabled }
    feature.define_singleton_method(:reverse_geocode) { |_| reverse_result }
    feature
  end

  it 'returns empty universal_classifications when the geocode feature is disabled' do
    DataCycleCore::Feature.stub(:[], nil) do
      result = subject.geocode({ 'address' => address })

      assert_equal([], result['universal_classifications'])
    end
  end

  it 'geocodes an address to a location and tags it geocoded' do
    DataCycleCore::Feature.stub(:[], geocode_feature(geocode_result: point)) do
      DataCycleCore::Concept.stub(:for_tree, concept_chain) do
        result = subject.geocode({ 'address' => address, 'location' => nil })

        assert_equal(point, result['location'])
        assert_includes(result['universal_classifications'], 'cid-1')
      end
    end
  end

  it 'removes the geocoded tag when geocoding fails' do
    DataCycleCore::Feature.stub(:[], geocode_feature(geocode_result: nil)) do
      DataCycleCore::Concept.stub(:for_tree, concept_chain) do
        result = subject.geocode({ 'address' => address, 'location' => nil, 'universal_classifications' => [] })

        assert_equal([], result['universal_classifications'])
      end
    end
  end

  it 'reverse geocodes a location to an address' do
    address_hash = DataCycleCore::OpenStructHash.new({ 'street_address' => 'Main 1' })
    DataCycleCore::Feature.stub(:[], geocode_feature(reverse_result: address_hash)) do
      DataCycleCore::Concept.stub(:for_tree, concept_chain) do
        result = subject.reverse_geocode({ 'location' => point, 'address' => {} })

        assert_kind_of(Hash, result['address'])
        assert_includes(result['universal_classifications'], 'cid-1')
      end
    end
  end

  it 'removes the reverse_geocoded tag when reverse geocoding fails' do
    DataCycleCore::Feature.stub(:[], geocode_feature(reverse_result: nil)) do
      DataCycleCore::Concept.stub(:for_tree, concept_chain) do
        result = subject.reverse_geocode({ 'location' => point, 'address' => {}, 'universal_classifications' => [] })

        assert_equal([], result['universal_classifications'])
      end
    end
  end

  it 'returns data unchanged when reverse geocode is disabled' do
    DataCycleCore::Feature.stub(:[], geocode_feature(reverse_enabled: false)) do
      result = subject.reverse_geocode({ 'location' => point, 'address' => {} })

      assert_equal([], result['universal_classifications'])
    end
  end
end
