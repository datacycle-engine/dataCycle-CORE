# frozen_string_literal: true

module DataCycleCore
  module ApiHelper
    include DataHashHelper

    def render_api_attribute(key:, definition:, value:, parameters: {}, content: nil, scope: :api)
      return if definition['type'] == 'classification' && !DataCycleCore::ClassificationService.visible_classification_tree?(definition['tree_label'], scope.to_s)

      api_version = @api_version || 2
      partials = [
        key.underscore.to_s,
        "#{definition['type'].underscore}_#{definition.try(:[], 'api').try(:[], 'partial').try(:underscore)}",
        "#{definition['type'].underscore}_#{definition.try(:[], 'validations').try(:[], 'format').try(:underscore)}",
        "#{definition.try(:[], 'compute').try(:[], 'type').try(:underscore)}_#{definition.try(:[], 'api').try(:[], 'partial').try(:underscore)}",
        definition.try(:[], 'compute').try(:[], 'type').try(:underscore).to_s,
        definition['type'].underscore.to_s,
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

    def included_linked?(name, linked_list)
      return if linked_list.blank?
      linked_list.map { |item| item.first == name }.inject(&:|)
    end

    def subtree_for(name, linked_list)
      linked_list.select { |item| item.first == name }.map { |item| item.drop(1) }.select(&:present?)
    end

    def api_cache_key(item, language, include_parameters, mode_parameters, api_subversion = nil)
      "#{item.class}_#{item.id}_#{item.first_available_locale(language)}_#{api_subversion}_#{item.updated_at}_#{item.template_updated_at}_#{include_parameters.join('_')}_#{mode_parameters.join('_')}"
    end
  end
end
