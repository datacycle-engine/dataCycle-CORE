# frozen_string_literal: true

module DataCycleCore
  module ApiHelper
    include DataHashHelper

    def api_default_attributes
      ['@id', '@type']
    end

    def render_api_attribute(key:, definition:, value:, parameters: {}, content: nil, scope: :api)
      return if definition['type'] == 'classification' && !definition['universal'] && !DataCycleCore::ClassificationService.visible_classification_tree?(definition['tree_label'], scope.to_s)

      api_property_definition = api_definition(definition)
      api_version = @api_version || 2
      if api_version == 4
        partials = [
          "#{(definition&.dig('compute', 'type') || definition&.dig('type')).underscore}_#{key.underscore}",
          (api_property_definition&.dig('partial')&.present? ? "#{(definition&.dig('compute', 'type') || definition&.dig('type')).underscore}_#{api_property_definition&.dig('partial')&.underscore}" : ''),
          api_property_definition&.dig('partial')&.underscore,
          definition['type'].underscore,
          'default'
        ].reject(&:blank?)
      else
        partials = [
          "#{definition['type'].underscore}_#{key.underscore}",
          "#{definition['type'].underscore}_#{api_property_definition&.dig('partial')&.underscore}",
          "#{definition['type'].underscore}_#{definition.dig('validations', 'format')&.underscore}",
          "#{definition&.dig('compute', 'type')&.underscore}_#{api_property_definition.dig('partial')&.underscore}",
          definition&.dig('compute', 'type')&.underscore,
          definition&.dig('virtual', 'type')&.underscore,
          definition['type'].underscore,
          'default'
        ].reject(&:blank?)
      end

      api_partials = partials.dup.map { |p| "data_cycle_core/api/v#{api_version}/api_base/attributes/#{p}" }
      if @api_subversion.present?
        subversion_partials = partials.dup.map { |p| "data_cycle_core/api/v#{api_version}/#{@api_subversion}/api_base/attributes/#{p}" }
        api_partials = subversion_partials + api_partials
      end

      return first_existing_partial(api_partials), parameters.merge({ key: key, definition: definition, value: value, content: content })
    end

    def first_existing_partial(partials)
      partials.each do |partial|
        next unless lookup_context.exists?(partial, [], true)
        return partial
      end
    end

    def attribute_key(key, definition)
      definition.dig('api', 'v4', 'name') || definition.dig('api', 'name') || key.camelize(:lower)
    end

    def api_definition(definition, api_version = @api_version)
      return {} if definition.dig('api').blank?

      definition['api'].except('v1', 'v2', 'v3', 'v4').merge(definition.dig('api', "v#{api_version}") || {})
    end

    def attribute_disabled?(definition, api_version = @api_version)
      return definition.dig('api', "v#{api_version}", 'disabled') if definition.dig('api', "v#{api_version}")&.key?('disabled')
      definition.dig('api', 'disabled') || false
    end

    def included_attribute?(name, attribute_list)
      return if attribute_list.blank?
      attribute_list.map { |item| item.first == name }.inject(&:|)
    end

    def virtual_attribute(content, key, definition, language)
      DataCycleCore::Utility::Virtual::Base.virtual_values(key, definition, content, language)
    end

    def subtree_for(name, attribute_list)
      attribute_list.select { |item| item.first == name }.map { |item| item.drop(1) }.select(&:present?)
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

    def load_value_object(content, key, value, languages, definition = nil)
      data_value = nil
      single_value = !content.translatable_property_names.include?(key) || (languages.size == 1 && content.available_locales.map(&:to_s).include?(languages.first))
      if single_value
        data_value = api_value_format(value, definition)
      else
        data_value = []

        content.translations.each do |translation|
          next unless languages.include?(translation.locale)
          I18n.with_locale(translation.locale) do
            data_value << { '@language' => I18n.locale, '@value' => api_value_format(content.send(key + '_overlay'), definition) } if content.send(key + '_overlay').present?
          end
        end
      end
      data_value
    end

    def load_object_value_object(content, key, o_key, value, languages, definition)
      data_value = nil
      api_property_definition = api_definition(definition)

      single_value = definition['storage_location'] != 'translated_value' || (languages.size == 1 && content.available_locales.map(&:to_s).include?(languages.first))
      if single_value
        data_value = api_value_format(value, api_property_definition)
      else
        data_value = []

        content.translations.where(locale: languages).each do |translation|
          I18n.with_locale(translation.locale) do
            o_value = content.send(key + '_overlay')&.try(o_key)
            data_value << { '@language' => I18n.locale, '@value' => api_value_format(o_value, api_property_definition) } if o_value.present?
          end
        end
      end
      data_value
    end

    def load_embedded_object(content, key, languages, definition)
      return nil if languages.blank?

      return content.load_embedded_objects(key, nil, false, languages, true).includes(:translations, :classifications) unless definition['translated']

      languages.map(&:to_sym).reduce(nil) do |v, locale|
        t_value = I18n.with_locale(locale) { content.load_embedded_objects(key, nil, false, [locale], true).includes(:translations, :classifications) }

        if v.nil?
          t_value
        else
          v.or(t_value)
        end
      end
    end

    def api_value_format(value, definition)
      return value if definition.blank? || definition.dig('format').blank?
      "#{definition.dig('format', 'prepend')}#{value}#{definition.dig('format', 'append')}"
    end

    def api_cache_key(item, language, include_parameters, mode_parameters, api_subversion = nil, full = nil, linked_filter_id = nil, is_linked = false, depth = 0)
      include_params = is_linked ? include_parameters.dup << 'is_linked' : include_parameters
      if item.is_a?(DataCycleCore::Thing)
        "#{item.class.name.underscore}_#{item.id}_#{Array(language).join('_')}_#{@api_version}_depth#{depth}_#{api_subversion}_#{item.updated_at.to_i}_#{item.template_updated_at.to_i}_#{include_params&.sort&.join('_')}_#{mode_parameters&.sort&.join('_')}_#{linked_filter_id}"
      elsif item.is_a?(DataCycleCore::Thing::History)
        "#{item.class.name.underscore}_#{item.id}_#{Array(language).join('_')}_#{@api_version}_depth#{depth}_#{api_subversion}_#{item.updated_at.to_i}_#{item.template_updated_at.to_i}_#{include_params&.sort&.join('_')}_#{mode_parameters&.sort&.join('_')}"
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
        key = "#{item.class.name.underscore}/#{item.id}_#{Array(language)&.sort&.join(',')}_#{api_subversion}_#{item.updated_at.to_i}_#{item.template_updated_at.to_i}_include/#{include_params}_fields/#{field_params}_lsf/#{linked_stored_filter_id}_trees/#{tree_params}"
      elsif item.is_a?(DataCycleCore::ClassificationAlias) || item.is_a?(DataCycleCore::ClassificationTreeLabel) || item.is_a?(DataCycleCore::Schedule)
        key = "#{item.class.name.underscore}/#{item.id}_#{Array(language)&.sort&.join(',')}_#{api_subversion}_#{item.updated_at.to_i}_include/#{include_params}_fields/#{field_params}_trees/#{tree_params}_#{full}"
      else
        raise NotImplementedError
      end

      key
    end

    def api_plain_context(languages)
      display_language = nil
      display_language = languages if languages.is_a?(::String)
      display_language = languages.first if languages.is_a?(::Array) && languages.size == 1 && languages.first.is_a?(::String)
      display_language = I18n.default_locale if languages.blank?

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
          'odta' => 'https://ds.sti2.org/'
        }.compact
      ]
    end

    def api_plain_meta(count, pages)
      {
        total: count,
        pages: pages
      }
    end

    def api_plain_links(contents = nil)
      contents ||= @contents
      object_url = (lambda do |params|
        File.join(request.protocol + request.host + ':' + request.port.to_s, request.path) + '?' + params.to_query
      end)
      if request.request_method == 'POST'
        common_params = {}
      else
        common_params = @permitted_params.to_h.reject { |k, _| ['id', 'format', 'page', 'api_subversion'].include?(k) }
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
