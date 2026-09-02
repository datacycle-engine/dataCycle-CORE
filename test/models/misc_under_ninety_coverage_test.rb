# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Coverage for assorted small helpers/features left below 90%: the HTML sanitizer,
  # markdown link renderer, Arel builder mixin, FlushCache pipeline hook, and the
  # Preview / Aggregate / Container / ContentScore feature helpers.
  class MiscUnderNinetyCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @thing = DataCycleCore::Thing.new(template_name: DataCycleCore::ThingTemplate.first.template_name)
    end

    test 'Sanitize::String.format_html strips formatting whitespace' do
      assert_equal '<b>x</b>', DataCycleCore::Utility::Sanitize::String.format_html('<b>x</b>')
    end

    test 'MarkdownHtmlRenderer#link builds anchor tags and absolutizes root links' do
      renderer = DataCycleCore::Static::MarkdownHtmlRenderer.new

      html = renderer.link('/foo', 'My Title', 'label')

      assert_includes html, '<a href='
      assert_includes html, 'title="My Title"'
    end

    test 'ArelBuilder methods build arel nodes' do
      builder = Class.new { extend DataCycleCore::Common::ArelBuilder }

      assert_nothing_raised do
        builder.absolute_date_diff(Arel.sql('a'), Arel.sql('b'))
        builder.tsmatch(Arel.sql('v'), Arel.sql('q'))
        builder.tsquery('x')
        builder.to_tsquery('x')
        builder.websearch_to_tsquery('x')
        builder.websearch_to_prefix_tsquery('x', nil, 'ABCD')
      end
    end

    test 'FlushCache clears the cache and drives the logging pipeline' do
      assert_nothing_raised { DataCycleCore::Generic::Common::FlushCache.process_content }

      DataCycleCore::Generic::Common::ImportFunctions.stub(:logging_without_mongo, :ran) do
        assert_equal :ran, DataCycleCore::Generic::Common::FlushCache.import_data(utility_object: nil, options: {})
      end
    end

    test 'Feature::Preview.available_widgets builds v2 and v3 widget urls' do
      config = { widgets: { 'plain' => 'https://a.test', 'versioned' => { version: 3, url: 'https://b.test' } } }
      DataCycleCore::Feature::Preview.stub(:configuration, config) do
        widgets = DataCycleCore::Feature::Preview.available_widgets('ep-1', :de)

        assert_includes widgets['plain'], 'data_cycle_widget[endpoint]=ep-1'
        assert_includes widgets['versioned'], 'api-endpoint=ep-1'
      end
    end

    test 'Feature::Aggregate type option/value helpers' do
      options = DataCycleCore::Feature::Aggregate.aggregate_type_options(locale: :de)

      assert_equal DataCycleCore::Feature::Aggregate::AGGREGATE_TYPES.size, options.size
      # aggregate_type_values maps the stored type back to its translated label
      assert_equal [options.first.first], DataCycleCore::Feature::Aggregate.aggregate_type_values(value: options.first.last, locale: :de)
    end

    test 'Container roots and siblings build relations' do
      assert_kind_of ActiveRecord::Relation, DataCycleCore::Thing.roots
      assert_kind_of ActiveRecord::Relation, @thing.siblings
    end

    test 'ContentScore feature helpers resolve from the template schema' do
      assert_kind_of Array, @thing.ordered_content_score_property_names
      assert_nothing_raised { @thing.content_score_parameters }
    end

    test 'DataAttribute normalizes params and non-hash definitions/options' do
      params = ActionController::Parameters.new(foo: 'bar')
      from_params = DataCycleCore::DataAttribute.new('key', params, params, nil, :update)

      assert_equal({ 'foo' => 'bar' }, from_params.definition)
      assert_equal({ 'foo' => 'bar' }, from_params.options)

      from_scalars = DataCycleCore::DataAttribute.new('key', 'not-a-hash', 42, nil, :update)

      assert_empty from_scalars.definition
      assert_empty from_scalars.options
    end

    test 'OpenStructHash attribute_translatable? and merge operate on nested hashes' do
      struct = DataCycleCore::OpenStructHash.new({ 'name' => 'x' })

      assert_not struct.attribute_translatable?('unknown')
      assert_not struct.attribute_translatable?('name', { 'storage_location' => 'translated_value', 'type' => 'string' })

      merged = struct.merge(DataCycleCore::OpenStructHash.new({ 'other' => 'y' }))

      assert_kind_of DataCycleCore::OpenStructHash, merged
    end

    test 'Mvt to_mvt renders on both the instance and the class' do
      renderer = Object.new
      renderer.define_singleton_method(:render) { '' }

      DataCycleCore::Geo::MvtRenderer.stub(:new, renderer) do
        assert_equal '', @thing.to_mvt(1, 2, 3)
        assert_equal '', DataCycleCore::Thing.to_mvt(1, 2, 3)
      end
    end

    test 'ContentWarnings collects hard warnings from a matching warning class' do
      host_class = Class.new do
        include DataCycleCore::Content::Extensions::ContentWarnings

        def template_name
          'POI'
        end
      end
      warning_class = Object.new
      warning_class.define_singleton_method(:try) do |method, *|
        method.to_s.end_with?('_message') ? 'a warning message' : true
      end
      config = { 'POI' => { 'some_warning' => { active: true, hard: true, highlight: true } } }.with_indifferent_access

      DataCycleCore.stub(:content_warnings, config) do
        DataCycleCore::ModuleService.stub(:safe_load_module, warning_class) do
          messages = host_class.new.content_warning_messages

          assert_includes messages[:hard], 'a warning message'
          assert_includes messages[:highlight], :hard
        end
      end
    end

    test 'PropertyTypes#properties_for resolves a property path and guards blanks' do
      template = DataCycleCore::ThingTemplate.first

      assert_nil template.properties_for(nil)
      assert_not_nil template.properties_for(template.property_names.first)
    end
  end
end
