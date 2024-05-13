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

      def type?(attribute_type)
        definition&.[]('type') == attribute_type
      end

      def render_params
        parameters.merge(to_h.slice(:key, :definition, :value, :content))
      end

      def overlay_attribute?
        definition.dig('features', 'overlay', 'overlay_for').present? &&
          MasterData::Templates::Extensions::Overlay.overlay_attribute?(key&.attribute_name_from_key)
      end

      def specific_scope
        parameters&.dig(:options, :edit_scope)&.to_s
      end

      def render_overlay_attribute?
        content.external? && specific_scope == 'edit'
      end

      def add_overlay_properties!
        css_class = parameters.dig(:options, :class).to_s.split

        if DataHashService.present?(value)
          css_class.push('dc-overlay-visible')
        else
          css_class.delete('dc-overlay-visible')
        end

        parameters[:options][:class] = css_class.uniq.join(' ') if css_class.present?
      end

      def add_has_overlay_options!
        css_class = parameters.dig(:options, :class).to_s.split
        css_class << 'dc-has-overlay'

        parameters[:options][:class] = css_class.uniq.join(' ')
        parameters[:options][:additional_attribute_partials] = ['data_cycle_core/contents/overlay/overlay_type_selector']
      end

      def attribute_has_overlay?
        render_overlay_attribute? && !!definition&.dig('overlay')
      end
    end

    def attribute_viewer_allowed(options)
      return render('data_cycle_core/contents/viewers/attribute_group', options.render_params) if options.type?('attribute_group')

      return unless can?(:show, DataCycleCore::DataAttribute.new(
                                  options.key,
                                  options.definition,
                                  options.parameters[:options],
                                  options.content,
                                  options.scope
                                )) &&
                    (options.content.nil? || options.content&.allowed_feature_attribute?(options.key.attribute_name_from_key))

      return if options.type?('classification') &&
                !options.definition['universal'] &&
                !DataCycleCore::ClassificationService.visible_classification_tree?(
                  options.definition['tree_label'],
                  options.parameters.dig(:options, :force_render) ? DataCycleCore.classification_visibilities.select { |c| c.start_with?(options.scope.to_s) } : options.scope.to_s
                )

      return if options.type?('slug') && options.parameters[:parent]&.embedded?

      true
    end

    def render_specific_translatable_title_attribute_viewer(locale:, content:, key:, **args)
      I18n.with_locale(locale) do
        label_html = ActionView::OutputBuffer.new
        label_html << content.try(key)
        definition = content.properties_for('name')
        label_html << render('data_cycle_core/contents/content_score', key: 'name', content: contextual_content({ content: }.merge(args.slice(:parent))), definition:) if definition&.key?('content_score')

        label_html
      end
    end

    def render_attribute_viewer(**)
      options = RenderMethodOptions.new(**, defaults: RENDER_VIEWER_ARGUMENTS)

      allowed = attribute_viewer_allowed(options)
      return allowed unless allowed.is_a?(TrueClass)

      if attribute_translatable?(*options.to_h.slice(:key, :definition, :content).values) ||
         object_has_translatable_attributes?(options.content, options.definition)
        render_translatable_attribute_viewer(options)
      else
        render_untranslatable_attribute_viewer(options)
      end
    end

    def render_translatable_attribute_viewer(options)
      render 'data_cycle_core/contents/viewers/translatable_field', **options.to_h
    end

    def render_specific_translatable_attribute_viewer(**)
      options = RenderMethodOptions.new(**, defaults: RENDER_VIEWER_ARGUMENTS)

      I18n.with_locale(options.locale) do
        options.value ||= if options.parameters[:parent].nil?
                            options.content.try(options.key.attribute_name_from_key)
                          else
                            options.parameters[:parent]&.try(options.key.attribute_name_from_key)
                          end

        allowed = attribute_viewer_allowed(options)
        return allowed unless allowed.is_a?(TrueClass)

        render_untranslatable_attribute_viewer(options)
      end
    end

    def attribute_value_present?(value)
      DataCycleCore::DataHashService.present?(value)
    end

    def render_untranslatable_attribute_viewer(options)
      type = options.definition['type'].underscore_blanks

      partials = [
        options.definition&.dig('ui', 'show', 'partial').presence,
        "#{type}_#{options.key.attribute_name_from_key}",
        *feature_templates(options.key, options.definition, options.content),
        options.definition.dig('ui', 'show', 'type')&.underscore_blanks&.prepend(type, '_').presence,
        options.definition.dig('validations', 'format')&.underscore_blanks&.prepend(type, '_').presence,
        type.to_s
      ].compact

      partials.map! { |p| "data_cycle_core/contents/viewers/#{p}" }

      render_first_existing_partial(partials, options.render_params)
    end

    def render_attribute_history_viewer(**)
      options = RenderMethodOptions.new(**, defaults: RENDER_VIEWER_ARGUMENTS)
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
        render_first_existing_partial(partials, options.render_params)
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
        render('data_cycle_core/contents/grid/compact/attributes/translatable_field', params:, partial:)
      else
        render(partial, params)
      end
    end

    def contextual_content(local_assigns)
      is_thing = lambda { |item|
        item.class.in?([DataCycleCore::Thing, DataCycleCore::Thing::History, DataCycleCore::OpenStructHash])
      }

      return local_assigns[:parent] if is_thing.call(local_assigns[:parent])

      local_assigns[:content] if is_thing.call(local_assigns[:content])
    end

    def life_cycle_class(content, stage)
      html_classes = ['hollow button']
      html_classes = ['active'] if content.life_cycle_stage?(stage[:id])

      html_classes.push('disabled') unless can?(:set_life_cycle, content, stage)
      html_classes.push('before-active') if content.life_cycle_stage_index&.>(content.life_cycle_stage_index(stage[:id]))
      html_classes.push('after-active') if content.life_cycle_stage_index&.<(content.life_cycle_stage_index(stage[:id]))

      html_classes.join(' ')
    end

    def attribute_viewer_html_classes(key:, definition:, options:, parent: nil, **_args)
      html_classes = [
        'detail-type',
        key.attribute_name_from_key,
        definition.dig('type')&.underscore,
        options.dig('class')
      ]

      html_classes.push(definition.dig('ui', 'show', 'type').underscore) if definition.dig('ui', 'show', 'type').present?
      html_classes.push(options.dig(:mode) || 'has-changes edit') if options.dig(:item_diff).present?
      html_classes.push('is-embedded-title') if parent.is_a?(DataCycleCore::Thing) && parent.embedded_title_property_name.present? && key.attribute_name_from_key == parent.embedded_title_property_name

      html_classes.compact_blank!
      html_classes.uniq!
      html_classes.join(' ')
    end

    def attribute_viewer_data_attributes(key:, definition:, content: nil, options: nil, data_attributes: nil, data_label: nil, **_args)
      html_data = data_attributes.to_h.transform_values { |v| v.to_s.html_safe } # rubocop:disable Rails/OutputSafety
      html_data[:label] = data_label || translated_attribute_label(key, definition, content, options)
      html_data[:key] = key

      html_data
    end
  end
end
