# frozen_string_literal: true

module DataCycleCore
  RENDER_VIEWER_ARGUMENTS = {
    key: nil,
    definition: nil,
    value: nil,
    parameters: { options: {} },
    content: nil,
    scope: :show,
    prefix: nil,
    locale: nil,
    user: nil,
    defaults: nil,
    edit_scope: nil,
    force_render: nil,
    context: :viewer,
    readonly: false,
    value_loaded: false
  }.freeze

  RENDER_EDITOR_ARGUMENTS = RENDER_VIEWER_ARGUMENTS.deep_merge({
    parameters: { options: { edit_scope: 'edit' } },
    scope: :edit
  }).freeze

  DataAttributeOptions = Struct.new(*RENDER_VIEWER_ARGUMENTS.keys, keyword_init: true) do
    def initialize(**args)
      args[:value_loaded] = args.key?(:value) unless args.key?(:value_loaded)
      args[:defaults] = (args[:context] == :editor ? RENDER_EDITOR_ARGUMENTS : RENDER_VIEWER_ARGUMENTS).except(:value)
      args.reverse_merge!(args[:defaults])

      if args[:definition].is_a?(ActionController::Parameters)
        args[:definition] = args[:definition].permit!.to_h
      elsif args[:definition].is_a?(::Hash)
        args[:definition] = args[:definition].dc_deep_dup.with_indifferent_access
      elsif args[:content].present? && args[:key].present?
        args[:definition] ||= args[:content]&.properties_for(args[:key].attribute_name_from_key) || {}
      else
        args[:definition] = {}
      end

      args[:parameters].deep_merge!(args[:defaults][:parameters]) { |_k, v1, _v2| v1 }
      if args[:parameters][:options].is_a?(ActionController::Parameters)
        args[:parameters][:options] = args[:parameters][:options].permit!.to_h
      elsif args[:parameters][:options].is_a?(::Hash)
        args[:parameters][:options] = args[:parameters][:options].dc_deep_dup.with_indifferent_access
      end

      args[:parameters][:options] ||= args.dig(:defaults, :parameters, :options)
      args[:parameters][:options]
        .merge!(args[:definition]&.dig('ui', args[:scope].to_s, 'options') || {}) { |k, v1, v2| k == 'class' ? [v1, v2].compact_blank.join(' ') : v2 }

      args[:edit_scope] = args.dig(:parameters, :options, :edit_scope)
      args[:force_render] = args.dig(:parameters, :options, :force_render)
      args[:readonly] = args.dig(:parameters, :options, :readonly)

      super
    end

    def hash
      {
        context: context&.to_s,
        key: key&.to_s,
        definition: definition&.with_indifferent_access,
        content:,
        scope: scope&.to_s,
        force_render: force_render&.to_s,
        edit_scope: edit_scope&.to_s,
        embedded: embedded?,
        readonly: readonly&.to_s
      }.hash
    end

    def contextual_content
      is_thing = lambda { |item|
        item.class.in?([DataCycleCore::Thing, DataCycleCore::Thing::History, DataCycleCore::OpenStructHash])
      }

      return parameters[:parent] if is_thing.call(parameters[:parent])

      content if is_thing.call(content)
    end

    def value
      return self[:value] if value_loaded
      return if contextual_content.nil?

      self[:value_loaded] = true
      self[:value] = contextual_content.try(attribute_name)
      self[:value] = self[:value].page.per(DataCycleCore.linked_objects_page_size) if @value.is_a?(ActiveRecord::Relation) && (type?('linked') || type?('embedded'))
      self[:value]
    end

    def attribute_name
      key.attribute_name_from_key
    end

    def data_attribute_options
      { edit_scope:, force_render:, readonly: }.compact.with_indifferent_access
    end

    def embedded?
      !!parameters[:parent]&.embedded?
    end

    def type?(attribute_type)
      definition&.[]('type') == attribute_type
    end

    def render_params
      params = to_h.slice(:key, :definition, :content)
      params[:value] = value

      parameters.merge(params)
    end

    def overlay_attribute?
      definition.dig('features', 'overlay', 'overlay_for').present?
    end

    def computed_attribute?
      definition.key?('compute')
    end

    def virtual_attribute?
      definition.key?('virtual')
    end

    def attribute_group?
      type?('attribute_group')
    end

    def attribute_has_overlay?
      render_overlay_attribute? && definition&.dig('features', 'overlay', 'allowed')
    end

    def aggregated_attribute?
      definition&.dig('features', 'aggregate', 'allowed')
    end

    def aggregate_attribute?
      definition.dig('features', 'aggregate', 'aggregate_for').present?
    end

    def duplicate_options_for_attribute_name(attribute_name)
      return unless content&.property?(attribute_name)

      duplicated = to_h.dc_deep_dup
      duplicated[:key] = key.replace_attribute_name_in_key(attribute_name)
      duplicated[:definition] = content.properties_for(duplicated[:key].attribute_name_from_key)

      self.class.new(**duplicated)
    end

    def options_for_aggregate_keys
      content&.aggregate_property_names_for(attribute_name)&.map do |aggregate_attribute_name|
        duplicate_options_for_attribute_name(aggregate_attribute_name).tap { |no| no.scope = :update }
      end
    end

    def options_for_overlay_keys
      content&.overlay_property_names_for(attribute_name)&.map do |overlay_attribute_name|
        duplicate_options_for_attribute_name(overlay_attribute_name).tap { |no| no.scope = :update }
      end
    end

    def options_for_original_key
      duplicate_options_for_attribute_name(
        definition.dig('features', 'aggregate', 'aggregate_for') ||
        definition.dig('features', 'overlay', 'overlay_for')
      )
    end

    def specific_scope
      edit_scope&.to_s
    end

    def render_overlay_attribute?
      (content.external? || content.aggregate_type_aggregate?) && specific_scope == 'edit'
    end

    def add_additional_attribute_properties!
      return unless overlay_attribute? || aggregate_attribute?

      css_class = parameters.dig(:options, :class).to_s.split
      css_class.push('dc-overlay', "dc-overlay-#{definition.dig('features', 'overlay', 'overlay_type')}") if overlay_attribute?
      css_class.push('dc-aggregate', "dc-aggregate-#{MasterData::Templates::AggregateTemplate::BASE_AGGREGATE_POSTFIX.delete_prefix('_')}") if aggregate_attribute?

      if DataHashService.present?(value)
        css_class.push('dc-overlay-visible') if overlay_attribute?
        css_class.push('dc-aggregate-visible') if aggregate_attribute?
      end

      parameters[:options][:class] = css_class.uniq.join(' ') if css_class.present?
    end

    def attribute_overlay_allowed?
      return false unless attribute_has_overlay?

      options_for_overlay_keys.any?(&:attribute_allowed?)
    end

    def attribute_aggregate_allowed?
      return false unless aggregated_attribute?

      options_for_aggregate_keys.any?(&:attribute_allowed?)
    end

    def add_additional_attribute_partials!
      return unless attribute_overlay_allowed? || attribute_aggregate_allowed?

      css_class = parameters.dig(:options, :class).to_s.split
      additional_attribute_partials = []
      css_class << 'dc-has-additional-attribute-partial'

      if attribute_overlay_allowed?
        css_class << 'dc-has-overlay'
        additional_attribute_partials << {
          partial: 'data_cycle_core/contents/additional_attribute_partials/additional_attribute_partial_selector',
          parent_html_classes: 'dc-has-additional-attribute-partial dc-has-overlay',
          locals: {
            key_prefix: 'overlay',
            check_box_types: -> { overlay_types(_1) }
          }
        }
      end

      if attribute_aggregate_allowed?
        css_class << 'dc-has-aggregate'
        additional_attribute_partials << {
          partial: 'data_cycle_core/contents/additional_attribute_partials/additional_attribute_partial_selector',
          parent_html_classes: 'dc-has-additional-attribute-partial dc-has-aggregate',
          locals: {
            key_prefix: 'aggregate',
            check_box_types: -> { aggregate_types(_1) }
          }
        }
      end

      # parameters[:options][:class] = css_class.uniq.join(' ')
      parameters[:options][:additional_attribute_partials] = additional_attribute_partials
    end

    def attribute_allowed?
      user.can_attribute?(self)
    end

    def add_editor_attributes!
      add_additional_attribute_properties!
      add_additional_attribute_partials!
    end

    def attribute_group_params
      path = context == :editor ? 'editors' : 'viewers'

      return "data_cycle_core/contents/#{path}/attribute_group", render_params
    end
  end
end
