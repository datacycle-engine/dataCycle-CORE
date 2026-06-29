# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Focused coverage for the TemplatePropertyContract rules that the template-validation
  # suite does not reach: the `asset` type rule and the three `additional_value_paths`
  # nested-shape rules plus the `additional_values_overlay` cross-check.
  class TemplatePropertyContractCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
    def call_contract(definition, property_name: 'some_property')
      contract = DataCycleCore::MasterData::Templates::TemplatePropertyContract.new
      contract.property_name = property_name
      contract.call(definition)
    end

    test 'rule(:type) flags an asset property missing an asset_type' do
      result = call_contract({ 'type' => 'asset' })

      assert result.errors.to_h.key?(:type)
    end

    test 'rule(:type) accepts an asset property with an asset_type' do
      result = call_contract({ 'type' => 'asset', 'asset_type' => 'image' })

      assert_not result.errors.to_h.key?(:type)
    end

    test 'additional_value_paths rules flag blank and inconsistent geo/title paths' do
      additional_value_paths = {
        'a' => nil, # blank path
        'b' => {
          'title' => 't',      # title present, geo missing -> "is missing" (geo)
          'x' => nil,          # blank nested value
          'sub' => { 'title' => 't2' }, # nested geo missing
          'sub2' => nil
        },
        'c' => {
          'geo' => 'g', # geo present, title missing -> "is missing" (title)
          'sub3' => { 'geo' => 'g2' } # nested title missing
        }
      }

      result = call_contract({
        'type' => 'string',
        'ui' => { 'edit' => { 'options' => {
          'additional_value_paths' => additional_value_paths,
          'additional_values_overlay' => ['nonexistent_key']
        } } }
      })
      messages = result.errors.map(&:text)

      assert(messages.any? { |m| m.include?('is blank') })
      assert(messages.any? { |m| m.include?('is missing') })
      assert(messages.any? { |m| m.include?('is not included in additional_value_paths') })
    end

    test 'additional_value_paths rule flags a completely blank value' do
      result = call_contract({
        'type' => 'string',
        'ui' => { 'edit' => { 'options' => { 'additional_value_paths' => {} } } }
      })

      assert(result.errors.map(&:text).any? { |m| m.include?('is blank') })
    end
  end
end
