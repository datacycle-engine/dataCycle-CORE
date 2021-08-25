# frozen_string_literal: true

module DataCycleCore
  module EditorHelper
    ATTRIBUTE_FIELD_PREFIX = 'thing[datahash]'
    EDITOR_ARGUMENTS = {
      key: nil,
      definition: nil,
      value: nil,
      parameters: { options: { edit_scope: 'edit' } },
      content: nil,
      scope: :edit,
      prefix: nil,
      locale: nil
    }.freeze

    EditorOptions = Struct.new(*EDITOR_ARGUMENTS.keys, keyword_init: true) do
      def initialize(**args)
        args.deep_merge!(EDITOR_ARGUMENTS) { |_k, v1, _v2| v1 }
        args[:parameters][:options] = (args[:parameters][:options]&.dc_deep_dup || {}).with_indifferent_access

        super(**args)
      end
    end

    def attribute_editable?(key, definition, options, content)
      @attribute_editable ||= Hash.new do |h, k|
        h[k] = can?(:edit, DataCycleCore::DataAttribute.new(k[0], k[1], k[2], k[3], :edit, k.dig(2, 'edit_scope')))
      end

      @attribute_editable[[key, definition, options, content]]
    end

    def attribute_editor_allowed(options)
      return if options.definition['type'] == 'slug' && options.parameters[:parent]&.embedded?
      return if options.definition['type'] == 'computed'

      return render_linked_viewer(options.to_h.slice(:key, :definition, :value, :parameters, :content)) if options.definition['type'] == 'linked' && options.definition['link_direction'] == 'inverse'

      return unless can?(:show, DataCycleCore::DataAttribute.new(
                                  options.key,
                                  options.definition,
                                  options.parameters[:options],
                                  options.content,
                                  options.scope,
                                  options.parameters.dig(:options, :edit_scope)
                                )) &&
                    (options.content.nil? || options.content&.allowed_feature_attribute?(options.key.attribute_name_from_key))

      return if options.definition['type'] == 'classification' && !DataCycleCore::ClassificationService.visible_classification_tree?(options.definition['tree_label'], options.scope.to_s)

      true
    end

    def render_attribute_editor(**args)
      options = EditorOptions.new(**args)

      allowed = attribute_editor_allowed(options)
      return allowed unless allowed.is_a?(TrueClass)

      partials = [
        options.definition&.dig('ui', options.parameters.dig(:options, :edit_scope), 'partial').presence,
        options.definition&.dig('ui', 'edit', 'partial').presence,
        "#{options.definition['type'].underscore_blanks}_#{options.key.attribute_name_from_key}",
        *feature_templates(options.key, options.definition, options.content),
        options.definition&.dig('ui', 'edit', 'type')&.underscore_blanks&.prepend(options.definition['type'].underscore_blanks, '_').presence,
        options.definition['type'].underscore_blanks.to_s
      ].compact

      partials = partials.map { |p| "data_cycle_core/contents/editors/#{p}" }

      options.parameters[:options][:readonly] = !attribute_editable?(options.key, options.definition, options.parameters[:options], options.content)
      options.parameters[:options] = add_attribute_options(options.parameters[:options], options.definition, options.scope)
      render_first_existing_partial(partials, options.parameters.merge(options.to_h.slice(:key, :definition, :value, :content)))
    end

    def render_translated_attribute(**args)
      options = EditorOptions.new(**args)

      I18n.with_locale(options.locale) do
        options.value ||= options.content.try(options.key.attribute_name_from_key.to_sym)

        render_attribute_editor options.to_h
      end
    end

    def render_translatable_editor(**args)
      options = EditorOptions.new(**args)

      allowed = attribute_editor_allowed(options)
      return allowed unless allowed.is_a?(TrueClass)

      render 'data_cycle_core/contents/editors/translatable_field', options.to_h
    end

    def render_translatable_attribute(**args)
      options = EditorOptions.new(**args)

      options.key = options.prefix + Array.wrap(options.key.is_a?(String) ? options.key.attribute_name_from_key : options.key).map { |k| "[#{k}]" if k != 'properties' }.join

      if options.content.translatable? && options.content.translatable_property?(options.key.attribute_name_from_key, options.definition) && I18n.available_locales.many?
        render_translatable_editor options.to_h
      else
        render_attribute_editor options.to_h
      end
    end
  end
end
