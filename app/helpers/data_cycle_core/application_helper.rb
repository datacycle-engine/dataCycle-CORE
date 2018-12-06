# frozen_string_literal: true

module DataCycleCore
  module ApplicationHelper
    DEFAULT_KEY_MATCHING = {
      alert: :alert,
      notice: :success,
      info: :info,
      secondary: :secondary,
      success: :success,
      error: :alert,
      warning: :warning,
      primary: :primary
    }.freeze

    def available_locales_with_names
      locales = Hash[I18n.available_locales.collect { |l| [l, I18n.t('locales.' + l.to_s, locale: DataCycleCore.ui_language).try(:capitalize)] }]
      locales[:all] = t('common.all', locale: DataCycleCore.ui_language)
      locales.sort_by { |_, v| v.to_s }.to_h
    end

    def display_flash_messages_new(closable: true)
      capture do
        flash.each do |key, value|
          alert_class = DEFAULT_KEY_MATCHING[key.to_sym]
          concat alert_box(value, alert_class, closable)
        end
      end
    end

    def display_flash_messages_resource(closable: true)
      capture do
        resource.errors.messages.each do |value|
          text_string = "#{value[0]} #{value[1][0]}"
          concat alert_box(text_string, :alert, closable)
        end
      end
    end

    # Returns the full title on a per-page basis.
    def full_title
      base_title = 'DataCycle'

      if content_for(:title).blank?
        base_title
      else
        content_for(:title) + ' | ' + base_title
      end
    end

    def previous_authorized_crumb
      breadcrumbs[0..-2].reverse.find(&:authorized)
    end

    def schema_path_from_key(key)
      key.gsub(/datahash/, 'properties').scan(/\[(.*?)\]/).flatten || []
    end

    def new_content_select_options(query: DataCycleCore::Thing, query_methods: [], content: nil, scope: nil)
      query = query.where(template: true)

      query_methods.presence&.map(&:stringify_keys)&.each do |query_method|
        if query.respond_to?(query_method['method_name']) && query_method.key?('value')
          query = query.try(query_method['method_name'], query_method['value'])
        elsif query.respond_to?(query_method['method_name'])
          query = query.try(query_method['method_name'])
        end
      end

      query.order(:template_name).select { |t| can?(:create, t, scope, { content: content }) }.map do |t|
        [
          t.template_name,
          "source_id=>#{t.id},source_table=>#{t.class.table_name}"
        ]
      end
    end

    def to_query_params(options_hash)
      params_hash = {}
      options_hash.each do |key, value|
        if value.is_a?(ActiveRecord::Base)
          params_hash[key] = { id: value&.id, class: value&.class&.name }
        elsif value.is_a?(ActiveRecord::Relation)
          params_hash[key] = { ids: value&.ids, class: value&.class&.name }
        else
          params_hash[key] = value
        end
      end
      params_hash
    end

    def add_attribute_options(options, definition, scope)
      attribute_options = definition.try(:[], 'ui').try(:[], scope.to_s).try(:[], 'options')
      attribute_options.nil? ? options : options.merge(attribute_options)
    end

    def feature_templates(key, definition, content)
      [
        definition&.dig('features').try(:keys),
        content&.schema&.dig('features')&.select { |_, v| v.is_a?(Hash) && v['attribute_keys'].presence&.include?(key.parameterize(separator: '_')) }&.keys,
        DataCycleCore.features.select { |_, v| v.is_a?(Hash) && v[:attribute_keys].presence&.include?(key.parameterize(separator: '_')) }.keys
      ].reject(&:blank?).flatten
    end

    def feature_attributes(content, prefix = '')
      DataCycleCore.features.keys.map { |f| "DataCycleCore::Feature::#{f.to_s.classify}".constantize.try("#{prefix}attribute_keys", content) }.flatten
    end

    def allowed_feature_attribute?(key, content)
      feature_attributes(content).include?(key) ? feature_attributes(content, 'allowed_').include?(key) : true
    end

    def render_content_partial(partial, parameters)
      raise "try to render content_partial that is not a thing: #{partial} || #{parameters}" unless ['thing', 'thing_history'].include?(parameters[:content].class.class_name.underscore)
      content_parameter = parameters[:content].schema['schema_type'].underscore
      partials = [
        "#{parameters[:content].template_name.parameterize(separator: '_')}_#{partial}",
        "#{content_parameter}_#{partial}",
        "content_#{partial}"
      ]

      render_first_existing_partial(partials, parameters)
    end

    def render_attribute_editor(key:, definition:, value:, parameters: {}, content: nil, scope: :edit)
      return render('data_cycle_core/contents/editors/hidden', key: key, definition: definition, value: value, content: content) unless can?(:show, DataCycleCore::DataAttribute.new(key, definition, parameters[:options], content, scope)) && allowed_feature_attribute?(key.attribute_name_from_key, content)

      if definition&.dig('ui', 'edit', 'partial').present?
        partials = [definition&.dig('ui', 'edit', 'partial')]
      else
        partials = [
          key.attribute_name_from_key,
          feature_templates(key, definition, content),
          "#{definition['type'].underscore}_#{definition.try(:[], 'ui').try(:[], 'edit').try(:[], 'type').try(:underscore)}",
          definition['type'].underscore.to_s
        ]
      end

      partials = partials.reject(&:blank?).flatten.map { |p| "data_cycle_core/contents/editors/#{p}" }

      # TODO: check if required ? refactor readonly
      parameters[:options]['readonly'] = !can?(:edit, DataCycleCore::DataAttribute.new(key, definition, parameters[:options], content, scope))

      parameters[:options] = add_attribute_options(parameters[:options], definition, scope)
      render_first_existing_partial(partials, parameters.merge({ key: key, definition: definition, value: value, content: content }))
    end

    def render_attribute_viewer(key:, definition:, value:, parameters: {}, content: nil, scope: :show)
      return unless can?(:show, DataCycleCore::DataAttribute.new(key, definition, parameters[:options], content, scope)) && allowed_feature_attribute?(key.attribute_name_from_key, content)

      if definition&.dig('ui', 'show', 'partial').present?
        partials = [definition&.dig('ui', 'show', 'partial')]
      else
        partials = [
          key.underscore.to_s,
          feature_templates(key, definition, content),
          "#{definition['type'].underscore}_#{definition.try(:[], 'ui').try(:[], 'show').try(:[], 'type').try(:underscore)}",
          "#{definition['type'].underscore}_#{definition.try(:[], 'validations').try(:[], 'format').try(:underscore)}",
          definition.dig('compute', 'type')&.underscore&.to_s,
          definition['type'].underscore.to_s
        ]
      end

      partials = partials.reject(&:blank?).flatten.map { |p| "data_cycle_core/contents/viewers/#{p}" }

      parameters[:options] = add_attribute_options(parameters[:options], definition, scope)
      render_first_existing_partial(partials, parameters.merge({ key: key, definition: definition, value: value, content: content }))
    end

    def render_attribute_history_viewer(key:, definition:, value:, parameters: {}, content: nil)
      partials = [
        key.underscore.to_s,
        definition.try(:[], 'ui').try(:[], 'history').try(:[], 'type').try(:underscore).to_s,
        "#{definition['type'].underscore}_#{definition.try(:[], 'validations').try(:[], 'format').try(:underscore)}",
        definition['type'].underscore.to_s
      ].reject(&:blank?).map { |p| "data_cycle_core/contents/history/#{p}" }
      begin
        render_first_existing_partial(partials, parameters.merge({ key: key, definition: definition, value: value, content: content }))
      rescue StandardError
        render_attribute_viewer key: key, definition: definition, value: value, parameters: parameters, content: content, scope: :history
      end
    end

    def render_linked_viewer(key:, definition:, value:, parameters: {}, content: nil)
      partials = [
        key.underscore.to_s,
        definition.try(:[], 'template_name').try(:parameterize).try(:underscore),
        content.try(:schema_type)&.underscore,
        'thing',
        'default'
      ].reject(&:blank?).map { |p| "data_cycle_core/contents/viewers/linked/#{p}" }

      render_first_existing_partial(partials, parameters.merge({ key: key, definition: definition, value: value, content: content }))
    end

    def render_linked_history_viewer(key:, definition:, value:, parameters: {}, content: nil)
      partials = [
        key.underscore.to_s,
        definition.try(:[], 'ui').try(:[], 'show').try(:[], 'type').try(:underscore).to_s,
        definition.try(:[], 'template_name').try(:parameterize).try(:underscore),
        'thing',
        'default'
      ].reject(&:blank?).map { |p| "data_cycle_core/contents/history/linked/#{p}" }

      render_first_existing_partial(partials, parameters.merge({ key: key, definition: definition, value: value, content: content }))
    end

    def render_asset_editor(key:, value:, definition:, parameters: {}, content: nil)
      partials = [
        definition.try(:[], 'asset_type').to_s.try(:underscore),
        'default'
      ].reject(&:blank?).map { |p| "data_cycle_core/contents/editors/asset/#{p}" }
      render_first_existing_partial(partials, parameters.merge({ key: key, definition: definition, value: value, content: content }))
    end

    def render_asset_viewer(key:, value:, definition:, parameters: {}, content: nil)
      partials = [
        definition.try(:[], 'asset_type').to_s.try(:underscore),
        'default'
      ].reject(&:blank?).map { |p| "data_cycle_core/contents/viewers/asset/#{p}" }
      render_first_existing_partial(partials, parameters.merge({ key: key, definition: definition, value: value, content: content }))
    end

    def content_tile(item:, parameters: {})
      partials = [
        item.try(:template_name)&.underscore_blanks,
        item.try(:schema_type)&.underscore_blanks,
        item&.class&.name&.demodulize&.underscore_blanks,
        'default'
      ].reject(&:blank?).map { |p| "data_cycle_core/contents/tiles/#{p}" }

      return first_existing_partial(partials), parameters.merge({ item: item })
    end

    def render_object_browser_partial(partial: 'tile', key:, definition:, parameters: {}, content: nil)
      partials = [
        definition.dig('template_name')&.underscore_blanks,
        parameters&.dig(:object)&.try(:schema_type)&.underscore_blanks,
        'default'
      ].reject(&:blank?).map { |p| "data_cycle_core/contents/editors/object_browser/#{p}_#{partial}" }
      render_first_existing_partial(partials, parameters.merge({ key: key, definition: definition, content: content }))
    end

    def render_embedded_object_partial(partial: 'detail', key:, definition:, parameters: {}, content: nil)
      partials = [
        key.attribute_name_from_key,
        'default'
      ].reject(&:blank?).map { |p| "data_cycle_core/contents/editors/embedded/#{p}_#{partial}" }

      render_first_existing_partial(partials, parameters.merge({ key: key, definition: definition, content: content }))
    end

    def render_new_form(new_template: nil, parameters: {})
      partials = [
        new_template&.template_name&.underscore_blanks,
        new_template&.schema_type&.underscore_blanks,
        'default'
      ].reject(&:blank?).map { |p| "data_cycle_core/contents/new/#{p}_form" }

      render_first_existing_partial(partials, parameters.merge({ new_template: new_template }))
    end

    private

    def render_first_existing_partial(partials, parameters)
      partials.each_with_index do |partial, idx|
        logger.debug "  Try rendering partial #{partial} ..."
        return render(partial, parameters)
      rescue ActionView::MissingTemplate => e
        logger.debug "  Try rendering partial #{partial} ... [NOT FOUND]"
        raise e if idx == partials.size - 1
      end
    end

    def alert_box(value, alert_class, closable)
      options = { class: "flash flash-notification callout #{alert_class}" }
      options[:data] = { closable: '' } if closable
      content_tag(:div, options) do
        if value.is_a?(String)
          concat value.to_s
        elsif value.is_a?(Hash)
          concat value.map { |k, v| content_tag(:b, k.titleize + ': ') + v.join(', ') }.join(', ').html_safe
        else
          concat value.to_s
        end
        concat close_link if closable
      end
    end

    def close_link
      button_tag(
        class: 'close-button',
        type: 'button',
        data: { close: '' },
        aria: { label: 'Dismiss alert' }
      ) do
        content_tag(:span, '&times;'.html_safe, aria: { hidden: true })
      end
    end

    def yield_content!(content_key)
      view_flow.content.delete(content_key)
    end

    def first_existing_partial(partials)
      partials.each_with_index do |partial, _idx|
        next unless lookup_context.exists?(partial, [], true)

        return partial
      end
    end
  end
end
