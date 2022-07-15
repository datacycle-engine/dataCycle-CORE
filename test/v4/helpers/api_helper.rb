# frozen_string_literal: true

module DataCycleCore
  module V4
    module ApiHelper
      # exclude inverse properties
      EXCLUDED_PROPERTIES =
        [
          'overlay', # overlays must be tested in a spererate task
          'schedule', # legacy property for events
          'sub_event', # legacy property for events
          'about', # TODO: check if should be tested with full thing
          'subject_of', # TODO: check if should be tested with full thing
          'is_linked_to', # TODO: check if should be tested with full thing
          'linked_thing', # TODO: check if should be tested with full thing
          # 'member', # TODO: check if should be tested with full thing
          'external_key', # only used for embedded during import
          'country_code_api', # legacy property for API v2 + v3
          'gender_api', # legacy property for API v2 + v3
          'asset', # disabled asset property for tests,
          'tour', # active after tour refactoring
          'additional_information',
          'explicit_copyright_notice', # TODO: fix if final solution is in sight ... everywhere ... will change again ...
          'publication_schedule', # creativeWorks: publicationSchedule
          'release_status_comment', # creativeWorks: publicationSchedule
          'dc_potential_action', # TODO: temporary attribute will be moded to potential_action,
          'validity_schedule', # TODO: check if should be tested with full thing
          'slug',
          'work_translation',
          'copyright_notice_override',
          'copyright_notice_computed',
          'attribution_name',
          'translation_of_work',
          'source',
          'comment',
          'image_id',
          'visibility',
          'photographer',
          'restrictions',
          'mandatory_license',
          'internal_content_score',
          'external_content_score'
        ].freeze

      def assert_api_count_result(count)
        assert_response :success
        assert_equal(response.content_type, 'application/json; charset=utf-8')
        json_data = JSON.parse(response.body)
        assert_equal(2, json_data['@context'].size)
        assert_equal(count, json_data['@graph'].size)
        assert_equal(count, json_data['meta']['total'].to_i)
        assert(json_data.key?('links'))
      end

      def assert_api_default_sections
        assert_response :success
        assert_equal(response.content_type, 'application/json; charset=utf-8')
        json_data = JSON.parse(response.body)
        assert_equal(2, json_data['@context'].size)
        assert(json_data['@graph'].size.positive?)
        assert(json_data.key?('meta'))
        assert(json_data.key?('links'))
      end

      def assert_full_thing_datahash(thing)
        filled_keys = thing.get_data_hash.select { |_k, v| v.present? }.keys
        excluded_keys = EXCLUDED_PROPERTIES + DataCycleCore.internal_data_attributes + excluded_properties_for(thing) + thing.virtual_property_names
        assert_equal([], thing.property_names - filled_keys - excluded_keys)
      end

      def assert_translated_datahash(datahash, thing)
        assert_equal(datahash.keys.sort, (thing.translatable_property_names + thing.untranslatable_embedded_property_names - thing.computed_property_names - EXCLUDED_PROPERTIES).sort)
      end

      def assert_translated_thing(thing, locale)
        assert(thing.available_locales.include?(locale.to_sym))
      end

      def assert_attributes(json_validate, required_attributes, attributes, &block)
        assert_json_attributes(json_validate, &block)
        attributes.each { |a| required_attributes.delete(a) }
      end

      def assert_translated_attributes(json_validate, required_attributes, attributes, &block)
        assert_translated_json_attributes(json_validate, &block)
        attributes.each { |a| required_attributes.delete(a) }
      end

      def translated_value(thing, attribute, languages)
        languages.map do |locale|
          {
            '@language' => locale,
            '@value' => I18n.with_locale(locale.to_sym) { attribute.split('.').inject(thing, &:send) }
          }
        end
      end

      def assert_json_attributes(json_validate)
        compare_json = yield
        json = json_validate.dup.slice(*compare_json.keys)
        assert_equal(compare_json, json)
        compare_json.each_key { |a| json_validate.delete(a) }
      end

      def assert_translated_json_attributes(json_validate)
        compare_json = sort_translated_attributes(yield)
        json = sort_translated_attributes(json_validate.dup.slice(*compare_json.keys))
        assert_equal(compare_json, json)
        compare_json.each_key { |a| json_validate.delete(a) }
      end

      def assert_classifications(json_validate, classifications)
        json_classifications = json_validate.dig('dc:classification').sort_by { |c| c['@id'] }
        assert_equal(json_classifications, classifications.sort_by { |c| c['@id'] })
        json_validate.delete('dc:classification')
      end

      def assert_linked(json_validate, required_attributes, attributes)
        compare_json = yield
        json = json_validate.dup.slice(*compare_json.keys)
        compare_json.each_key do |attribute|
          assert_equal(compare_json.dig(attribute).sort_by { |c| c['@id'] }, json.dig(attribute).sort_by { |c| c['@id'] })
        end
        compare_json.each_key { |a| json_validate.delete(a) }
        attributes.each { |a| required_attributes.delete(a) }
      end

      def assert_context(json_context, language)
        assert_equal(2, json_context.size)
        assert_equal('https://schema.org/', json_context.first)
        validator = DataCycleCore::V4::Validation::Context.context(language)
        assert_equal({}, validator.call(json_context.second).errors.to_h)
      end

      def required_validation_attributes(thing)
        excluded_keys = EXCLUDED_PROPERTIES + DataCycleCore.internal_data_attributes + excluded_properties_for(thing) + thing.virtual_property_names
        thing.property_names - excluded_keys
      end

      def required_multilingual_validation_attributes(thing)
        required_validation_attributes(thing) - thing.translatable_property_names
      end

      def excluded_properties_for(content)
        content.name_property_selector do |definition|
          (
            definition['type'] == 'classification'
          ) && !api_enabled?(definition)
        end
      end

      def api_enabled?(definition)
        return true if definition.dig('api', 'v4', 'disabled') == false && definition.dig('api', 'v4')&.key?('disabled')
        return true if definition.dig('api', 'disabled') == false && definition.dig('api')&.key?('disabled')
        false
      end

      private

      def sort_translated_attributes(attributes)
        attributes.map { |k, v|
          if v.is_a?(::Hash)
            [k, sort_translated_attributes(v)]
          elsif v.is_a?(::Array) && v.detect { |c| c.is_a?(::Hash) && c['@language'].blank? }
            [k, v.map { |c| sort_translated_attributes(c) }]
          elsif v.is_a?(::Array)
            [k, v.sort_by { |c| c['@language'] }]
          else
            [k, v]
          end
        }&.to_h
      end
    end
  end
end
