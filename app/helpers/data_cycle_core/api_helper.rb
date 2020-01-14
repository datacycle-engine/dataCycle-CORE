# frozen_string_literal: true

module DataCycleCore
  module ApiHelper
    include DataHashHelper

    def api_default_attributes
      ['@id', '@type', '@language', 'name']
    end

    def render_api_attribute(key:, definition:, value:, parameters: {}, content: nil, scope: :api)
      return if definition['type'] == 'classification' && !DataCycleCore::ClassificationService.visible_classification_tree?(definition['tree_label'], scope.to_s)

      api_property_definition = api_definition(definition)
      api_version = @api_version || 2
      partials = [
        "#{definition['type'].underscore}_#{key.underscore}",
        "#{definition['type'].underscore}_#{api_property_definition&.dig('partial')&.underscore}",
        "#{definition['type'].underscore}_#{definition.dig('validations', 'format')&.underscore}",
        "#{definition&.dig('compute', 'type')&.underscore}_#{api_property_definition.dig('partial')&.underscore}",
        definition&.dig('compute', 'type')&.underscore,
        definition['type'].underscore,
        'default'
      ].reject(&:blank?)

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
      definition.dig('api', "v#{api_version}") || definition.dig('api') || {}
    end

    def included_attribute?(name, attribute_list)
      return if attribute_list.blank?
      attribute_list.map { |item| item.first == name }.inject(&:|)
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

    def load_value_object(content, key, value, languages)
      data_value = nil
      single_value = !content.translatable_property_names.include?(key) || (languages.size == 1 && content.available_locales.map(&:to_s).include?(languages.first))
      if single_value
        data_value = value
      else
        data_value = []

        content.translations.each do |translation|
          next unless languages.include?(translation.locale)
          I18n.with_locale(translation.locale) do
            data_value << { '@language' => I18n.locale, '@value' => content.send(key) } if content.send(key).present?
          end
        end
      end
      data_value
    end

    def api_cache_key(item, language, include_parameters, mode_parameters, api_subversion = nil, full = nil)
      if item.is_a?(DataCycleCore::Thing)
        "#{item.class.name.underscore}_#{item.id}_#{Array(language).join('_')}_#{@api_version}_#{api_subversion}_#{item.updated_at.to_i}_#{item.template_updated_at.to_i}_#{include_parameters&.sort&.join('_')}_#{mode_parameters&.sort&.join('_')}"
      elsif item.is_a?(DataCycleCore::ClassificationAlias)
        "#{item.class.name.underscore}_#{item.id}_#{Array(language).join('_')}_#{@api_version}_#{api_subversion}_#{item.updated_at.to_i}_#{include_parameters&.sort&.join('_')}_#{mode_parameters&.sort&.join('_')}_#{full}"
      elsif item.is_a?(DataCycleCore::ClassificationTreeLabel) || item.is_a?(DataCycleCore::Schedule)
        "#{item.class.name.underscore}_#{item.id}_#{Array(language).join('_')}_#{@api_version}_#{api_subversion}_#{item.updated_at.to_i}_#{include_parameters.sort.join('_')}_#{mode_parameters&.sort&.join('_')}_#{full}"
      else
        raise NotImplementedError
      end
    end
  end
end
