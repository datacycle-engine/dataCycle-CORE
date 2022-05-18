# frozen_string_literal: true

module DataCycleCore
  module AttributeViewerHelper
    RENDER_VIEWER_ARGUMENTS = {
      key: nil,
      definition: nil,
      value: nil,
      parameters: { options: {} },
      content: nil,
      scope: :show,
      prefix: nil,
      locale: nil
    }.freeze

    RenderMethodOptions = Struct.new(*RENDER_VIEWER_ARGUMENTS.keys.push(:defaults), keyword_init: true) do
      def initialize(**args)
        args.reverse_merge!(args[:defaults])
        args[:parameters].deep_merge!(args[:defaults][:parameters]) { |_k, v1, _v2| v1 }
        args[:parameters][:options] = (args[:parameters][:options] || {})
          .dc_deep_dup
          .with_indifferent_access
          .merge!(args[:definition]&.dig('ui', args[:scope].to_s, 'options') || {})

        super(**args)
      end
    end

    def attribute_viewer_allowed(options)
      return unless can?(:show, DataCycleCore::DataAttribute.new(
                                  options.key,
                                  options.definition,
                                  options.parameters[:options],
                                  options.content,
                                  options.scope
                                )) &&
                    (options.content.nil? || options.content&.allowed_feature_attribute?(options.key.attribute_name_from_key))

      return if options.definition['type'] == 'classification' &&
                !options.definition['universal'] &&
                !DataCycleCore::ClassificationService.visible_classification_tree?(
                  options.definition['tree_label'],
                  options.parameters.dig(:options, :force_render) ? DataCycleCore.classification_visibilities.select { |c| c.start_with?(options.scope.to_s) } : options.scope.to_s
                )

      return if options.definition['type'] == 'slug' && options.parameters[:parent]&.embedded?

      true
    end

    def render_specific_translatable_title_attribute_viewer(locale:, content:, key:, **_args)
      I18n.with_locale(locale) do
        content.try(key)
      end
    end

    def render_attribute_viewer(**args)
      options = RenderMethodOptions.new(**args, defaults: RENDER_VIEWER_ARGUMENTS)

      allowed = attribute_viewer_allowed(options)
      return allowed unless allowed.is_a?(TrueClass)

      if attribute_translatable?(*options.to_h.slice(:key, :definition, :content).values) ||
         object_has_translatable_attributes?(options.content, options.definition)
        render_translatable_attribute_viewer(**options.to_h)
      else
        render_untranslatable_attribute_viewer(**options.to_h)
      end
    end

    def render_translatable_attribute_viewer(**args)
      options = RenderMethodOptions.new(**args, defaults: RENDER_VIEWER_ARGUMENTS)

      render 'data_cycle_core/contents/viewers/translatable_field', options.to_h
    end

    def render_specific_translatable_attribute_viewer(**args)
      options = RenderMethodOptions.new(**args, defaults: RENDER_VIEWER_ARGUMENTS)

      I18n.with_locale(options.locale) do
        options.value ||= if options.parameters[:parent].nil?
                            options.content.try(options.key.attribute_name_from_key)
                          else
                            options.parameters[:parent]&.try(options.key.attribute_name_from_key)
                          end

        allowed = attribute_viewer_allowed(options)
        return allowed unless allowed.is_a?(TrueClass)

        render_untranslatable_attribute_viewer(**options.to_h)
      end
    end

    def render_untranslatable_attribute_viewer(**args)
      options = RenderMethodOptions.new(**args, defaults: RENDER_VIEWER_ARGUMENTS)

      type = options.definition['type'].underscore_blanks
      type = options.definition.dig('compute', 'type').underscore_blanks.to_s if options.definition.dig('compute', 'type').present?

      partials = [
        options.definition&.dig('ui', 'show', 'partial').presence,
        "#{type}_#{options.key.attribute_name_from_key}",
        *feature_templates(options.key, options.definition, options.content),
        options.definition.dig('ui', 'show', 'type')&.underscore_blanks&.prepend(type, '_').presence,
        options.definition.dig('validations', 'format')&.underscore_blanks&.prepend(type, '_').presence,
        type.to_s
      ].compact

      partials.map! { |p| "data_cycle_core/contents/viewers/#{p}" }

      render_first_existing_partial(partials, options.parameters.merge(options.to_h.slice(:key, :definition, :value, :content)))
    end

    def render_attribute_history_viewer(**args)
      options = RenderMethodOptions.new(**args, defaults: RENDER_VIEWER_ARGUMENTS)
      options.scope = :history

      partials = [
        options.key.attribute_name_from_key,
        options.definition&.dig('ui', 'history', 'type')&.underscore_blanks.presence,
        "#{options.definition['type'].underscore_blanks}_#{options.definition&.dig('validations', 'format')&.underscore_blanks}".presence,
        options.definition['type'].underscore_blanks.presence
      ]
      partials.compact!
      partials.map! { |p| "data_cycle_core/contents/history/#{p}" }

      begin
        render_first_existing_partial(partials, options.parameters.merge(options.to_h.slice(:key, :definition, :value, :content)))
      rescue StandardError
        render_attribute_viewer options.to_h
      end
    end

    def render_linked_content_warnings(content, params)
      if I18n.available_locales.many? && content&.translatable?
        render('data_cycle_core/contents/grid/attributes/translatable_warnings', params)
      else
        tag.span(
          render('data_cycle_core/contents/grid/attributes/warnings', params),
          class: 'linked-content-warnings'
        )
      end
    end

    def render_translatable_linked_field(content, partial, params)
      if I18n.available_locales.many? && content&.translatable?
        render('data_cycle_core/contents/grid/compact/attributes/translatable_field', params: params, partial: partial)
      else
        render(partial, params)
      end
    end

    def contextual_content(local_assigns)
      local_assigns[:parent] || local_assigns[:content]
    end
  end
end
