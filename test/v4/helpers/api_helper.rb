# frozen_string_literal: true

module DataCycleCore
  module V4
    module ApiHelper
      EXCLUDED_PROPERTIES =
        [
          'overlay', # overlays must be tested in a spererate task
          'schedule', # legacy property for events
          'sub_event', # legacy property for events
          'subject_of', # TODO: check if should be tested with full thing
          'super_event', # TODO: check if should be tested with full thing
          'is_linked_to', # TODO: check if should be tested with full thing
          'linked_thing', # TODO: check if should be tested with full thing
          'external_key' # only used for embedded during import
        ].freeze

      def assert_api_count_result(count)
        assert_response :success
        assert_equal(response.content_type, 'application/json')
        json_data = JSON.parse(response.body)
        assert_equal(count, json_data['@graph'].size)
        assert_equal(count, json_data['meta']['total'].to_i)
        assert_equal(true, json_data.key?('links'))
      end

      def assert_full_thing_datahash(thing)
        filled_keys = thing.get_data_hash.select { |_k, v| v.present? }.keys
        excluded_keys = EXCLUDED_PROPERTIES + DataCycleCore.internal_data_attributes + excluded_properties_for(thing)
        assert_equal([], thing.property_names - filled_keys - excluded_keys)
      end

      def assert_attributes(json_validate, required_attributes, attributes)
        assert_json_attributes(json_validate) do
          yield
        end
        attributes.each { |a| required_attributes.delete(a) }
      end

      def assert_json_attributes(json_validate)
        compare_json = yield
        json = json_validate.dup.slice(*compare_json.keys)
        assert_equal(compare_json, json)
        compare_json.each_key { |a| json_validate.delete(a) }
      end

      def assert_classifications(json_validate, classifications)
        json_classifications = json_validate.dig('dc:classification').sort_by { |c| c['@id'] }
        assert_equal(json_classifications, classifications.sort_by { |c| c['@id'] })
        json_validate.delete('dc:classification')
      end

      def required_validation_attributes(thing)
        excluded_keys = EXCLUDED_PROPERTIES + DataCycleCore.internal_data_attributes + excluded_properties_for(thing)
        thing.property_names - excluded_keys
      end

      def excluded_properties_for(content)
        content.name_property_selector { |definition| definition['type'] == 'classification' && api_enabled?(definition) == false }
      end

      def api_enabled?(definition)
        return true if definition.dig('api', 'v4', 'disabled') == false && definition.dig('api', 'v4')&.key?('disabled')
        return true if definition.dig('api', 'disabled') == false && definition.dig('api')&.key?('disabled')
        false
      end
    end
  end
end