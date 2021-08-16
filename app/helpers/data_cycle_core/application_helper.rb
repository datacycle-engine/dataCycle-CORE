# frozen_string_literal: true

module DataCycleCore
  module ApplicationHelper
    include DownloadHelpers
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
      @available_locales_with_names ||= Hash.new do |h, key|
        h[key] = I18n
          .t('locales', locale: key)
          .slice(*I18n.available_locales)
          .transform_values(&:capitalize)
          .sort_by { |_, v| v.to_s }
          .to_h
      end

      @available_locales_with_names[active_ui_locale]
    end

    def available_locales_with_all
      @available_locales_with_all ||= Hash.new do |h, key|
        if I18n.available_locales&.many?
          h[key] = available_locales_with_names.reverse_merge({ all: t('common.all', locale: active_ui_locale) })
        else
          h[key] = available_locales_with_names
        end
      end

      @available_locales_with_all[active_ui_locale]
    end

    def ice_cube_select_options
      IceCube::Rule::INTERVAL_TYPES.except([:secondly, :minutely, :hourly, :monthly]).prepend(:single_occurrence).map { |r| [t("schedule.#{r}", locale: active_ui_locale), "IceCube::#{r.to_s.classify}Rule", { 'data-type': r }] }
    end

    def display_flash_messages_new(closable: true)
      capture do
        flash.each do |key, value|
          alert_class = DEFAULT_KEY_MATCHING[key.to_sym]
          concat alert_box(value, alert_class, closable)
        end
      end
    end

    def show_external_connections?(content)
      can?(:show_external_connections, content) &&
        (
          content.try(:external_source) ||
            content.try(:external_systems).present?
        )
    end

    def data_link_permission_icon(permission)
      case permission
      when 'download'
        tag.i(class: 'fa fa-download', aria_hidden: true)
      when 'read'
        tag.i(class: 'fa fa-eye', aria_hidden: true)
      when 'write'
        tag.i(class: 'fa fa-pencil', aria_hidden: true)
      end
    end

    def mode_icon(mode, version = nil)
      title = t("view_modes.#{mode}", locale: active_ui_locale)
      title += " (#{version})" if version.present?
      case mode
      when 'grid' then tag.i(class: 'fa fa-th', aria_hidden: true, title: title)
      when 'list' then tag.i(class: 'fa fa-th-list', aria_hidden: true, title: title)
      when 'tree' then tag.i(class: 'fa fa-sitemap', aria_hidden: true, title: title)
      end
    end

    def result_count(mode, result_count, content_class)
      if mode.in?(['classification_alias', 'ca_recursive', 'container'])
        result_count&.positive? ? number_with_delimiter(result_count.to_i, locale: active_ui_locale) : '-'
      else
        t("common.#{content_class}_count_html", count: result_count.to_i, delimited_count: number_with_delimiter(result_count.to_i, locale: active_ui_locale), locale: active_ui_locale)
      end
    end

    def mode_link(mode, selected, params_hash)
      case mode
      when 'tree'
        capture do
          if DataCycleCore::ClassificationTreeLabel.visible('tree_view').many?
            concat(tag.span(mode_icon(mode), data: { toggle: 'tree-view-selector' }, class: selected ? 'selected' : nil))
            concat(
              tag.div(class: 'dropdown-pane no-bullet align-right', id: 'tree-view-selector', data: { dropdown: true, hover: true, hover_pane: true }) do
                concat(
                  tag.ul(class: 'no-bullet') do
                    DataCycleCore::ClassificationTreeLabel.visible('tree_view').presence&.each do |tree_label|
                      concat(tag.li(link_to_unless(tree_label.id == params_hash[:ctl_id], tree_label.name, params_hash.except(:ct_id, :con_id, :ctl_id, :cpt_id, :reset).merge({ mode: mode, ctl_id: tree_label.id }))))
                    end
                  end
                )
              end
            )
          elsif DataCycleCore::ClassificationTreeLabel.visible('tree_view').present?
            tree_label = DataCycleCore::ClassificationTreeLabel.visible('tree_view').first
            link_to_unless(tree_label.id == params_hash[:ctl_id], mode_icon(mode, tree_label.name), params_hash.except(:ct_id, :con_id, :ctl_id, :cpt_id, :reset).merge({ mode: mode, ctl_id: tree_label.id }))
          end
        end
      else
        link_to_unless selected, mode_icon(mode), params_hash.except(:ct_id, :con_id, :ctl_id, :cpt_id, :reset).merge(mode: mode)
      end
    end

    def valid_mode(mode)
      case mode
      when 'list', 'tree' then mode
      else 'grid'
      end
    end

    # Returns the full title on a per-page basis.
    def full_title
      base_title = 'dataCycle'

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

    def content_view_cache_key(item:, locale: 'de', mode:, watch_list:)
      "#{item.class.name.underscore}_#{item.id}_#{locale}_#{item.updated_at&.to_i}_#{item.template_updated_at&.to_i}_#{mode}_#{watch_list&.id}"
    end

    def new_content_select_options(query: DataCycleCore::Thing.all, query_methods: [], content: nil, scope: nil, limit: nil, ordered_array: nil)
      query = query.where(template: true)
      query_methods.presence&.map(&:stringify_keys)&.each do |query_method|
        if query.respond_to?(query_method['method_name']) && query_method.key?('value')
          query = query.try(query_method['method_name'], query_method['value'])
        elsif query.respond_to?(query_method['method_name'])
          query = query.try(query_method['method_name'])
        end
      end

      query = query.each.select { |t| can?(:create, t, scope, { content: content }) }
      query = query.sort_by { |t| ordered_array.index(t.template_name).to_i } if ordered_array.present?
      query = query.first(limit.to_i) if limit.present?
      query.sort_by(&:template_name)
    end

    def to_query_params(options_hash)
      params_hash = {}
      options_hash.each do |key, value|
        if value.is_a?(ActiveRecord::Base)
          params_hash[key] = { id: value&.id, class: value&.class&.name }
        elsif value.is_a?(ActiveRecord::Relation)
          params_hash[key] = { ids: value&.ids, class: value&.klass&.name }
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
      DataCycleCore::FeatureService.enabled_features(content&.schema || definition, key.attribute_name_from_key)
    end

    def new_dialog_config(template, except = nil, filter = nil)
      if DataCycleCore.new_dialog.key?(template&.template_name&.underscore_blanks)
        DataCycleCore.new_dialog.dig(template&.template_name&.underscore_blanks) || {}
      elsif DataCycleCore.new_dialog.key?(template&.schema_type&.underscore_blanks)
        DataCycleCore.new_dialog.dig(template&.schema_type&.underscore_blanks) || {}
      else
        DataCycleCore.new_dialog.dig('default')
      end.transform_values { |v| v&.select { |t| t.include?(filter.to_s) }&.map { |t| t.remove('**list').squish }&.except(except) }
    end

    def new_attribute_labels(template)
      template&.schema&.dig('properties')&.slice(*new_dialog_config(template, nil, '**list').values.flatten)&.map { |k, v| v['type'] == 'object' ? v['properties']&.map { |o_k, o_v| [o_k, o_v.slice('type', 'label', 'ui')] }.to_h : { k => v.slice('type', 'label', 'ui') } }&.reduce({}, :merge)
    end

    def uploader_validation_to_text(value, parents = ['uploader', 'validation'])
      if value.is_a? Hash
        return_html = ''
        value.each do |k, v|
          return_html += uploader_validation_to_text(v, parents + [k.to_s])
        end
        return_html
      elsif parents[-2] == 'file_size'
        "<li>#{I18n.t(parents.join('.'), data: ApplicationController.helpers.number_to_human_size(value, locale: active_ui_locale), locale: active_ui_locale)}</li>"
      else
        "<li>#{I18n.t(parents.join('.'), data: value.is_a?(Array) ? value.join(', ') : value.try(:to_s), locale: active_ui_locale)}</li>"
      end
    end

    def uploader_validation(asset_type:)
      if asset_type == 'text_file'
        return {} unless can?(:create, DataCycleCore::DataLink)

        return (DataCycleCore.uploader_validations[:text_file] || {}).with_indifferent_access.merge({
          class: 'DataCycleCore::TextFile',
          translation: DataCycleCore::TextFile.model_name.human(count: 1, locale: active_ui_locale),
          translation_description: t('uploader.description.text_file', locale: active_ui_locale, default: '')
        })
      end

      templates = DataCycleCore::Thing.includes(:translations).select("DISTINCT ON (things.id, asset_type) *, property_name.value ->> 'asset_type' AS asset_type").from("things, jsonb_each(schema -> 'properties') property_name").where("things.template = ? AND (value ->> 'asset_type' = ? OR things.template_name IN (?))", true, asset_type, DataCycleCore.features.dig(:external_media_archive, :enabled) ? DataCycleCore::Feature::ExternalMediaArchive.get_template_name(asset_type) : nil)

      creatable = false
      templates.each do |t|
        creatable ||= (t.content_type?('embedded') ? t.parent_templates&.any? { |pt| can?(:create, pt, 'asset') } : can?(:create, t, 'asset'))
      end

      uploader_model = "data_cycle_core/#{asset_type}".classify.safe_constantize

      return {} unless creatable && uploader_model

      {
        format: uploader_model.uploaders[:file].new&.extension_white_list || [],
        class: uploader_model.name,
        translation: uploader_model.model_name.human(count: 1, locale: active_ui_locale),
        translation_description: t("uploader.description.#{uploader_model.name.demodulize.underscore}", locale: active_ui_locale, default: '')
      }.with_indifferent_access.merge(DataCycleCore.uploader_validations[uploader_model.name.demodulize.underscore.to_sym] || {})
    end

    def render_content_partial(partial, parameters)
      raise "try to render content_partial that is not a thing: #{partial} || #{parameters}" unless ['thing', 'thing_history'].include?(parameters[:content].class.class_name.underscore)

      partials = [
        'content'
      ]
      unless parameters[:default]
        partials.unshift(
          parameters[:content].template_name.underscore_blanks,
          parameters[:content].schema_type.underscore_blanks
        )
      end

      partials = partials.map { |p| "data_cycle_core/contents/#{p}_#{partial}" }

      render_first_existing_partial(partials, parameters)
    end

    def attribute_editable?(key, definition, options, content)
      @attribute_editable ||= Hash.new do |h, k|
        h[k] = can?(:edit, DataCycleCore::DataAttribute.new(k[0], k[1], k[2], k[3], :edit, k.dig(2, 'edit_scope')))
      end

      @attribute_editable[[key, definition, options, content]]
    end

    def render_attribute_editor(key:, definition:, value:, parameters: { options: { edit_scope: 'edit' } }, content: nil, scope: :edit)
      parameters[:options] = (parameters[:options] || {}).with_indifferent_access
      edit_scope = parameters.dig(:options, :edit_scope)

      return if definition['type'] == 'slug' && parameters[:parent]&.embedded?

      return render_linked_viewer(key: key, definition: definition, value: value, parameters: parameters, content: content) if definition['type'] == 'linked' && definition['link_direction'] == 'inverse'

      return unless can?(:show, DataCycleCore::DataAttribute.new(key, definition, parameters[:options], content, scope, edit_scope)) && (content.nil? || content&.allowed_feature_attribute?(key.attribute_name_from_key))

      return if definition['type'] == 'classification' && !DataCycleCore::ClassificationService.visible_classification_tree?(definition['tree_label'], scope.to_s)

      partials = [
        definition&.dig('ui', edit_scope, 'partial').presence,
        definition&.dig('ui', 'edit', 'partial').presence,
        "#{definition['type'].underscore_blanks}_#{key.attribute_name_from_key}",
        *feature_templates(key, definition, content),
        definition&.dig('ui', 'edit', 'type')&.underscore_blanks&.prepend(definition['type'].underscore_blanks, '_').presence,
        definition['type'].underscore_blanks.to_s
      ].compact

      partials = partials.map { |p| "data_cycle_core/contents/editors/#{p}" }

      parameters[:options][:readonly] = !attribute_editable?(key, definition, parameters[:options], content)
      parameters[:options] = add_attribute_options(parameters[:options], definition, scope)
      render_first_existing_partial(partials, parameters.merge({ key: key, definition: definition, value: value, content: content }))
    end

    def render_attribute_viewer(key:, definition:, value:, parameters: {}, content: nil, scope: :show)
      return unless can?(:show, DataCycleCore::DataAttribute.new(key, definition, parameters[:options], content, scope)) && content&.allowed_feature_attribute?(key.attribute_name_from_key)

      return if definition['type'] == 'classification' && !definition['universal'] && !DataCycleCore::ClassificationService.visible_classification_tree?(definition['tree_label'], parameters.dig(:options, :force_render) ? DataCycleCore.classification_visibilities.select { |c| c.start_with?(scope.to_s) } : scope.to_s)

      return if definition['type'] == 'slug' && parameters[:parent]&.embedded?

      type = definition['type'].underscore_blanks
      type = definition.dig('compute', 'type').underscore_blanks.to_s if definition.dig('compute', 'type').present?

      partials = [
        definition&.dig('ui', 'show', 'partial').presence,
        "#{type}_#{key.attribute_name_from_key}",
        *feature_templates(key, definition, content),
        definition.dig('ui', 'show', 'type')&.underscore_blanks&.prepend(type, '_').presence,
        definition.dig('validations', 'format')&.underscore_blanks&.prepend(type, '_').presence,
        type.to_s
      ].compact

      partials = partials.map { |p| "data_cycle_core/contents/viewers/#{p}" }

      parameters[:options] = add_attribute_options(parameters[:options], definition, scope)

      render_first_existing_partial(partials, parameters.merge({ key: key, definition: definition, value: value, content: content }))
    end

    def render_attribute_history_viewer(key:, definition:, value:, parameters: {}, content: nil)
      partials = [
        key.attribute_name_from_key,
        definition&.dig('ui', 'history', 'type')&.underscore_blanks,
        "#{definition['type'].underscore_blanks}_#{definition&.dig('validations', 'format')&.underscore_blanks}",
        definition['type'].underscore_blanks
      ].reject(&:blank?).map { |p| "data_cycle_core/contents/history/#{p}" }
      begin
        render_first_existing_partial(partials, parameters.merge({ key: key, definition: definition, value: value, content: content }))
      rescue StandardError
        render_attribute_viewer key: key, definition: definition, value: value, parameters: parameters, content: content, scope: :history
      end
    end

    def render_linked_viewer(key:, definition:, value:, parameters: {}, content: nil)
      partials = [
        key.attribute_name_from_key,
        definition&.dig('template_name')&.underscore_blanks,
        'thing',
        'default'
      ].reject(&:blank?).map { |p| "data_cycle_core/contents/viewers/linked/#{p}" }

      render_first_existing_partial(partials, parameters.merge({ key: key, definition: definition, value: value, content: content }))
    end

    def render_linked_history_viewer(key:, definition:, value:, parameters: {}, content: nil)
      partials = [
        key.attribute_name_from_key,
        definition&.dig('ui', 'show', 'type')&.underscore_blanks,
        definition.dig('template_name')&.underscore_blanks,
        'thing',
        'default'
      ].reject(&:blank?).map { |p| "data_cycle_core/contents/history/linked/#{p}" }

      render_first_existing_partial(partials, parameters.merge({ key: key, definition: definition, value: value, content: content }))
    end

    def render_asset_editor(key:, value:, definition:, parameters: {}, content: nil)
      partials = [
        definition.dig('asset_type')&.underscore_blanks,
        'default'
      ].reject(&:blank?).map { |p| "data_cycle_core/contents/editors/asset/#{p}" }
      render_first_existing_partial(partials, parameters.merge({ key: key, definition: definition, value: value, content: content }))
    end

    def render_asset_viewer(key:, value:, definition:, parameters: {}, content: nil)
      value = value.first if value.is_a?(ActiveRecord::Relation) || value.is_a?(Array)
      partials = [
        value.try(:type)&.demodulize&.underscore_blanks,
        'default'
      ].reject(&:blank?).map { |p| "data_cycle_core/contents/viewers/asset/#{p}" }
      render_first_existing_partial(partials, parameters.merge({ key: key, definition: definition, value: value, content: content }))
    end

    def render_content_tile(item:, parameters: {}, mode: 'grid')
      partials = [
        item.try(:template_name)&.underscore_blanks,
        item.try(:schema_type)&.underscore_blanks,
        item.try(:content_type)&.underscore_blanks,
        item&.class&.name&.demodulize&.underscore_blanks,
        'default'
      ].reject(&:blank?).map { |p| "data_cycle_core/contents/#{mode}/#{p}" }

      render_first_existing_partial(partials, parameters.merge({ item: item }))
    end

    def render_content_tile_details(item:, parameters: {}, mode: 'grid')
      partials = [
        item.try(:template_name)&.underscore_blanks,
        item.try(:schema_type)&.underscore_blanks,
        item.try(:content_type)&.underscore_blanks,
        item&.class&.name&.demodulize&.underscore_blanks,
        'default'
      ].reject(&:blank?).map { |p| "data_cycle_core/contents/#{mode}/#{p}_details" }

      render_first_existing_partial(partials, parameters.merge({ item: item }))
    end

    def render_linked_partial(key:, definition:, parameters: {}, content: nil)
      partials = [
        definition.dig('template_name')&.underscore_blanks,
        parameters&.dig(:object)&.try(:schema_type)&.underscore_blanks,
        'default'
      ].reject(&:blank?).map { |p| "data_cycle_core/contents/grid/compact/#{p}" }
      render_first_existing_partial(partials, parameters.merge({ key: key, definition: definition, content: content }))
    end

    def render_linked_details(key:, definition:, parameters: {}, content: nil)
      partials = [
        definition.dig('template_name')&.underscore_blanks,
        parameters&.dig(:object)&.try(:schema_type)&.underscore_blanks,
        'default'
      ].reject(&:blank?).map { |p| "data_cycle_core/contents/editors/object_browser/#{p}_detail" }
      render_first_existing_partial(partials, parameters.merge({ key: key, definition: definition, content: content }))
    end

    def render_embedded_object_partial(key:, definition:, parameters: {}, content: nil)
      partials = [
        "#{definition['type'].underscore_blanks}_#{key.attribute_name_from_key}",
        definition['type'].underscore_blanks.to_s,
        'default'
      ].compact.map { |p| "data_cycle_core/contents/editors/embedded/#{p}" }

      render_first_existing_partial(partials, parameters.merge({ key: key, definition: definition, content: content }))
    end

    def render_advanced_filter_partial(parameters = {})
      partials = [
        ("#{parameters[:filter_type]}_#{parameters[:filter_advanced_type]}" if parameters[:filter_advanced_type].present?),
        parameters[:filter_type],
        'default'
      ].compact.map { |p| "data_cycle_core/application/filters/#{p}" }

      render_first_existing_partial(partials, parameters)
    end

    def render_advanced_filter_tags_partial(parameters = {})
      partials = [
        ("#{parameters[:filter_type]}_#{parameters[:filter_advanced_type]}" if parameters[:filter_advanced_type].present?),
        parameters[:filter_type],
        'default'
      ].compact.map { |p| "data_cycle_core/application/filters/tag_groups/#{p}" }

      render_first_existing_partial(partials, parameters)
    end

    def render_new_form(template: nil, parameters: {})
      partials = [
        template&.template_name&.underscore_blanks,
        template&.schema_type&.underscore_blanks,
        'default'
      ].reject(&:blank?).map { |p| "data_cycle_core/contents/new/#{p}" }

      render_first_existing_partial(partials, parameters.merge({ template: template }))
    end

    def link_to_condition(condition, name, options = {}, html_options = {}, &block)
      if condition
        link_to(name, options, html_options, &block)
      elsif block_given?
        block.arity <= 1 ? capture(name, &block) : capture(name, options, html_options, &block)
      else
        ERB::Util.html_escape(name)
      end
    end

    def conditional_tag(name, condition, options = nil, &block)
      if condition
        content_tag name, capture(&block), options
      else
        capture(&block)
      end
    end

    private

    def render_first_existing_partial(partials, parameters)
      partials.each do |partial|
        logger.debug("  Try partial #{partial} ... [NOT FOUND]") && next unless lookup_context.exists?(partial, partial.start_with?('data_cycle_core') ? [] : lookup_context.prefixes, true)

        logger.debug "  Rendered #{partial}"
        return render(partial, parameters)
      end

      nil
    end

    def alert_box(value, alert_class, closable)
      options = { class: "flash flash-notification callout #{alert_class}" }
      options[:data] = { closable: '' } if closable
      tag.div(options) do
        if value.is_a?(String)
          concat value.html_safe
        elsif value.is_a?(Hash)
          concat value.map { |k, v| tag.b(k.titleize + ': ') + v.join(', ') }.join(', ').html_safe
        else
          concat value.html_safe.to_s
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
        tag.span('&times;'.html_safe, aria: { hidden: true })
      end
    end

    def yield_content!(content_key)
      view_flow.content.delete(content_key)
    end
  end
end
