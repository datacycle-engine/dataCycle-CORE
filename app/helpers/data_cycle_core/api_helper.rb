# frozen_string_literal: true

module DataCycleCore
  module ApiHelper
    include DataHashHelper
    include ContentHelper

    def api_default_attributes
      ['@id', '@type']
    end

    def render_api_attribute(key:, definition:, value:, parameters: {}, content: nil, scope: :api)
      return if definition['type'] == 'classification' && !definition['universal'] && !DataCycleCore::ClassificationService.visible_classification_tree?(definition['tree_label'], scope.to_s)

      api_property_definition = api_definition(definition)
      api_version = @api_version || 2
      if api_version == 4
        partials = [
          "#{definition&.dig('type')&.underscore}_#{key.underscore}",
          (api_property_definition&.dig('partial').present? ? "#{definition&.dig('type')&.underscore}_#{api_property_definition&.dig('partial')&.underscore}" : ''),
          api_property_definition&.dig('partial')&.underscore,
          definition['type'].underscore,
          'default'
        ].reject(&:blank?)
      else
        partials = [
          "#{definition['type'].underscore}_#{key.underscore}",
          "#{definition['type'].underscore}_#{api_property_definition&.dig('partial')&.underscore}",
          "#{definition['type'].underscore}_#{definition.dig('validations', 'format')&.underscore}",
          definition['type'].underscore,
          'default'
        ].reject(&:blank?)
      end

      api_partials = partials.dup.map { |p| "data_cycle_core/api/v#{api_version}/api_base/attributes/#{p}" }
      if @api_subversion.present?
        subversion_partials = partials.dup.map { |p| "data_cycle_core/api/v#{api_version}/#{@api_subversion}/api_base/attributes/#{p}" }
        api_partials = subversion_partials + api_partials
      end

      return first_existing_partial(api_partials), parameters.merge({ key:, definition:, value:, content: })
    end

    def first_existing_partial(partials)
      partials.each do |partial|
        next unless lookup_context.exists?(partial, partial.start_with?('data_cycle_core') ? [] : lookup_context.prefixes, true)

        return partial
      end
    end

    def attribute_key(key, definition)
      (api_definition(definition)['name'].presence || key).to_s.camelize(:lower)
    end

    def api_definition(definition, api_version = @api_version, api_context = @api_context)
      return {} if definition[api_context].blank?

      definition[api_context].reject { |k, _v| k.to_s.match?(/v\d+/) }.merge(definition.dig(api_context, "v#{api_version}") || {})
    end

    def attribute_disabled?(definition, api_version = @api_version, api_context = @api_context)
      api_definition(definition, api_version, api_context)['disabled'] || false
    end

    def included_attribute?(name, attribute_list)
      return false if attribute_list.blank?
      return true if full_recursive?(attribute_list)

      attribute_list.pluck(0).intersection(Array.wrap(name)).any?
    end

    def subtree_for(name, attribute_list)
      return attribute_list if full_recursive?(attribute_list)

      attribute_list.select { |item| item.first == name }.map { |item| item.drop(1) }.select(&:present?)
    end

    def full_recursive?(attribute_list)
      attribute_list.first&.intersection(['full', 'recursive'])&.size&.==(2)
    end

    def inherit_options(new_options, options)
      new_options ||= {}

      new_options[:ancestor_ids] = options[:ancestor_ids].dup
      new_options[:languages] = options[:languages].dup

      new_options
    end

    def select_attributes(attribute_list)
      Array(attribute_list).map(&:first).compact
    end

    def serialize_language(language_array)
      language_array.join(',')
    end

    def in_language?(content, options)
      (content.embedded? && options.dig(:translatable_embedded)) || content.translatable? || options.dig(:languages).include?(content.first_available_locale.to_s)
    end

    def ordered_api_properties(validation:, type: nil)
      return if validation.nil? || validation['properties'].blank?

      validation['properties']
        .sort_by { |_, prop| prop['sorting'] }
        .filter do |key, prop|
          next false if INTERNAL_PROPERTIES.include?(key) || prop['sorting'].blank?
          next false if type.present? && prop['type'] != type
          next false if attribute_disabled?(prop) && prop['type'] != 'linked' # ignore linked disabled (legacy of bidirectional links)

          true
        end
    end

    def load_value_object(content, key, value, languages, definition = nil, expand_language = false)
      data_value = nil
      first_locale = Array.wrap(languages).first

      return api_value_format(value, definition) unless content.translatable_property_names.include?(key)
      single_value = languages.size == 1 && content.available_locales.map(&:to_s).include?(first_locale)

      if single_value && !expand_language
        data_value = I18n.with_locale(first_locale) { api_value_format(content.send(key + '_overlay'), definition) } || []

        if content.embedded_property_names.include?(key)
          data_value = DataCycleCore::Thing.none
          content.available_locales.map(&:to_s).each do |locale|
            records = data_value.to_a + I18n.with_locale(locale) { content.try(key + '_overlay') }.to_a
            records_ids = records.pluck(:id)
            data_value = DataCycleCore::Thing.by_ordered_values(records_ids).tap { |rel| rel.send(:load_records, records) }
          end
        end
      else
        data_value = []

        content.available_locales.map(&:to_s).intersection(Array.wrap(languages)).each do |locale|
          I18n.with_locale(locale) do
            o_value = content.send(key + '_overlay')
            data_value << { '@language' => I18n.locale, '@value' => api_value_format(o_value, definition) } if o_value.present?
          end
        end
      end

      data_value
    end

    def load_object_value_object(content, key, o_key, value, languages, definition, expand_language = false)
      data_value = nil
      api_property_definition = api_definition(definition)

      return api_value_format(value, api_property_definition) unless content.translatable_property_names.include?(key)

      single_value = (languages.size == 1 && content.available_locales.map(&:to_s).include?(languages.first)) && !expand_language

      if single_value
        data_value = api_value_format(value, api_property_definition)
      else
        data_value = []

        content.available_locales.map(&:to_s).intersection(Array.wrap(languages)).each do |locale|
          I18n.with_locale(locale) do
            o_value = content.send(key + '_overlay')&.try(o_key)
            data_value << { '@language' => I18n.locale, '@value' => api_value_format(o_value, api_property_definition) } if o_value.present?
          end
        end
      end

      data_value
    end

    def load_embedded_object(content, key, languages, _definition)
      return if languages.blank?
      return content.try(key + '_overlay') unless content.translatable_property_names.include?(key)

      data_value = DataCycleCore::Thing.none
      content.available_locales.map(&:to_s).each do |locale|
        records = (data_value.to_a + I18n.with_locale(locale) { content.try(key + '_overlay') }.to_a).uniq
        records_ids = records.pluck(:id)
        data_value = DataCycleCore::Thing.by_ordered_values(records_ids).tap { |rel| rel.send(:load_records, records) }
      end

      data_value
    end

    def api_value_format(value, definition)
      return value if definition.blank? || definition.dig('format').blank?
      return value if DataCycleCore::DataHashService.blank?(value)
      "#{definition.dig('format', 'prepend')}#{value}#{definition.dig('format', 'append')}"
    end

    def api_cache_key(item, language, include_parameters, mode_parameters, api_subversion = nil, full = nil, linked_filter_id = nil, is_linked = false, depth = 0)
      include_params = is_linked ? include_parameters.dup << 'is_linked' : include_parameters
      if item.is_a?(DataCycleCore::Thing)
        "#{item.class.name.underscore}_#{item.id}_#{Array(language).join('_')}_#{@api_version}_depth#{depth}_#{api_subversion}_#{item.updated_at.to_i}_#{item.cache_valid_since.to_i}_#{include_params&.sort&.join('_')}_#{mode_parameters&.sort&.join('_')}_#{linked_filter_id}"
      elsif item.is_a?(DataCycleCore::Thing::History)
        "#{item.class.name.underscore}_#{item.id}_#{Array(language).join('_')}_#{@api_version}_depth#{depth}_#{api_subversion}_#{item.updated_at.to_i}_#{item.cache_valid_since.to_i}_#{include_params&.sort&.join('_')}_#{mode_parameters&.sort&.join('_')}"
      elsif item.is_a?(DataCycleCore::ClassificationAlias)
        "#{item.class.name.underscore}_#{item.id}_#{Array(language).join('_')}_#{@api_version}_depth#{depth}_#{api_subversion}_#{item.updated_at.to_i}_#{include_params.sort.join('_')}_#{mode_parameters&.sort&.join('_')}_#{full}"
      elsif item.is_a?(DataCycleCore::ClassificationTreeLabel) || item.is_a?(DataCycleCore::Schedule)
        "#{item.class.name.underscore}_#{item.id}_#{Array(language).join('_')}_#{@api_version}_depth#{depth}_#{api_subversion}_#{item.updated_at.to_i}_#{include_params.sort.join('_')}_#{mode_parameters&.sort&.join('_')}_#{full}"
      else
        raise NotImplementedError
      end
    end

    # TODO: add section parameter
    def api_v4_cache_key(item, language, include_parameters, field_parameters, api_subversion = nil, full = nil, linked_stored_filter_id = nil, classification_trees = [])
      include_params = include_parameters&.sort&.inject([]) { |carrier, param| carrier << param.join('.') }&.join(',')
      field_params = field_parameters&.sort&.inject([]) { |carrier, param| carrier << param.join('.') }&.join(',')
      tree_params = classification_trees&.compact&.sort&.join(',')

      if item.is_a?(DataCycleCore::Thing) || item.is_a?(DataCycleCore::Thing::History)
        add_params = Digest::MD5.hexdigest("include/#{include_params}_fields/#{field_params}_lsf/#{linked_stored_filter_id}_trees/#{tree_params}_expand_language/#{@expand_language}")
        key = "#{item.class.name.underscore}/#{item.id}_#{Array(language)&.sort&.join(',')}_#{api_subversion}_#{item.updated_at.to_i}_#{item.cache_valid_since.to_i}_#{add_params}"
      elsif item.is_a?(DataCycleCore::ClassificationAlias) || item.is_a?(DataCycleCore::ClassificationTreeLabel) || item.is_a?(DataCycleCore::Schedule)
        add_params = Digest::MD5.hexdigest("include/#{include_params}_fields/#{field_params}_trees/#{tree_params}_#{full}_expand_language/#{@expand_language}")
        key = "#{item.class.name.underscore}/#{item.id}_#{Array(language)&.sort&.join(',')}_#{api_subversion}_#{item.updated_at.to_i}_#{add_params}"
      else
        raise NotImplementedError
      end

      key
    end

    def api_plain_context(languages, expanded = false)
      display_language = nil
      display_language = languages if languages.is_a?(::String)
      display_language = languages.first if languages.is_a?(::Array) && languages.size == 1 && languages.first.is_a?(::String)
      display_language = I18n.default_locale if languages.blank?
      display_language = nil if expanded

      [
        'https://schema.org/',
        {
          '@base' => api_v4_universal_url(id: nil) + '/',
          '@language' => display_language,
          'skos' => 'https://www.w3.org/2009/08/skos-reference/skos.html#',
          'dct' => 'http://purl.org/dc/terms/',
          'cc' => 'http://creativecommons.org/ns#',
          'dc' => 'https://schema.datacycle.at/',
          'dcls' => schema_url + '/',
          'odta' => 'https://odta.io/voc/',
          'sdm' => 'https://smartdatamodels.org/',
          'alps' => 'http://json-schema.org/draft-07/schema/destinationdata/schemas/2022-04/datatypes#/definitions/'
        }.compact
      ]
    end

    def api_plain_meta(count, pages)
      {
        total: count,
        pages:
      }
    end

    def api_plain_links(contents = nil)
      contents ||= @contents
      object_url = lambda do |params|
        File.join(request.protocol + request.host + ':' + request.port.to_s, request.path) + '?' + params.to_query
      end
      if request.request_method == 'POST'
        common_params = {}
      else
        common_params = @permitted_params.to_h.except('id', 'format', 'page', 'api_subversion')
      end
      links = {}
      links[:prev] = object_url.call(common_params.merge(page: { number: contents.prev_page, size: contents.limit_value })) if contents.prev_page
      links[:next] = object_url.call(common_params.merge(page: { number: contents.next_page, size: contents.limit_value })) if contents.next_page
      links
    end

    def merge_overlay(data, overlay)
      overlay.map { |key, value|
        next if value.blank?
        if key == 'dc:classification'
          data[key] ||= []
          { key => data[key] + value }
        elsif data[key].blank? || !key.in?(['dataCycleProperty', 'additionalProperty'])
          { key => value }
        else
          { key => data[key].reject { |item| item.dig('identifier').in?(value.map { |i| i.dig('identifier') }) } + overlay[key] }
        end
      }.reject(&:blank?).inject(&:merge) || {}
    end
  end
end
