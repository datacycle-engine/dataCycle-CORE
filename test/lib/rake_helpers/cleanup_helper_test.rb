# frozen_string_literal: true

require 'test_helper'
require 'rake_helpers/cleanup_helper'

module DataCycleCore
  class CleanupHelperTest < DataCycleCore::TestCases::ActiveSupportTestCase
    ItemStub = Struct.new(:config)

    test 'identify_external_source returns nil when the config is blank' do
      assert_nil CleanupHelper.identify_external_source(ItemStub.new(nil))
    end

    test 'identify_external_source extracts the module name from the endpoint' do
      item = ItemStub.new(
        {
          'download_config' => {
            'places' => { 'endpoint' => 'DataCycleCore::Generic::Feratel::Endpoint' }
          }
        }
      )

      assert_equal 'Feratel', CleanupHelper.identify_external_source(item)
    end

    test 'linked returns nil for an unknown external source' do
      assert_nil CleanupHelper.linked('UnknownSystem')
    end

    test 'linked resolves linked templates via template_name and stored_filter' do
      thing = Object.new
      thing.define_singleton_method(:linked_property_names) { ['by_template', 'by_filter', 'neither'] }
      thing.define_singleton_method(:properties_for) do |name|
        case name
        when 'by_template' then { 'template_name' => 'POI' }
        when 'by_filter' then { 'stored_filter' => [{ 'with_classification_aliases_and_treename' => { 'aliases' => ['Event', 'Tour'] } }] }
        else {}
        end
      end

      result = DataCycleCore::Thing.stub(:new, thing) do
        CleanupHelper.linked('MediaArchive')
      end

      assert_includes result, { relation: 'by_template', template: 'POI' }
      assert_includes result, { relation: 'by_filter', template: 'Event' }
      assert_includes result, { relation: 'by_filter', template: 'Tour' }
    end

    test 'embedded returns a mapping of embedded templates to their parents' do
      result = CleanupHelper.embedded

      assert_kind_of Hash, result
      result.each_value { |parents| assert_kind_of Array, parents }
    end

    test 'orphaned_embedded builds a relation filtering out linked things' do
      relation = CleanupHelper.orphaned_embedded(['POI'], 'Bild')

      assert_respond_to relation, :to_sql
      assert_nothing_raised { relation.limit(1).to_a }
    end
  end
end
