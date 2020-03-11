# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'

describe DataCycleCore::MasterData::ImportMixins do
  subject do
    DataCycleCore::MasterData::ImportMixins
  end

  describe 'loaded mixin_data' do
    let(:full) do
      {
        things: {
          meta_data: {
            name: 'meta_data',
            properties: {
              'more_meta_data' => { 'name' => 'sub_mixin', 'type' => 'mixin' },
              'prop1' => { 'label' => 'prop1', 'type' => 'string', 'storage_location' => 'value' }
            }
          },
          sub_mixin: {
            name: 'sub_mixin',
            properties: {
              'sub1' => { 'label' => 'sub1', 'type' => 'string', 'storage_location' => 'value' },
              'sub_sub' => { 'name' => 'sub_sub_mixin', 'type' => 'mixin' }
            }
          },
          sub_sub_mixin: {
            name: 'sub_sub_mixin',
            properties: {
              'sub_sub1' => { 'label' => 'sub_sub1', 'type' => 'string', 'storage_location' => 'value' }
            }
          }
        }
      }.with_indifferent_access
    end

    let(:simple) do
      { things: { sub_sub_mixin: full[:things][:sub_sub_mixin] } }
    end

    let(:one_replacement) do
      {
        things: {
          sub_mixin: full[:things][:sub_mixin],
          sub_sub_mixin: full[:things][:sub_sub_mixin]
        }
      }
    end

    it 'mixins without mixins remain unchanged' do
      expanded_data = subject.resolve(simple)
      assert_equal(expanded_data.dig(:things, :sub_sub_mixin, :properties).keys.sort, ['sub_sub1'])
      assert_equal(simple.with_indifferent_access, expanded_data.with_indifferent_access)
    end

    it 'mixins get replaced with the content of another mixin' do
      expanded_data = subject.resolve(one_replacement)
      assert_equal(expanded_data.dig(:things, :sub_sub_mixin, :properties).keys.sort, ['sub_sub1'])
      assert_equal(expanded_data.dig(:things, :sub_mixin, :properties).keys.sort, ['sub1', 'sub_sub1'])
    end

    it 'mixins also work rucursively' do
      expanded_data = subject.resolve(full)
      assert_equal(expanded_data.dig(:things, :sub_sub_mixin, :properties).keys.sort, ['sub_sub1'])
      assert_equal(expanded_data.dig(:things, :sub_mixin, :properties).keys.sort, ['sub1', 'sub_sub1'])
      assert_equal(expanded_data.dig(:things, :meta_data, :properties).keys.sort, ['prop1', 'sub1', 'sub_sub1'])
    end
  end
end
