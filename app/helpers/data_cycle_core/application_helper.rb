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

    DATALINK_ICONS = {
      'download' => 'fa-download',
      'read' => 'fa-eye',
      'write' => 'fa-pencil'
    }.freeze

    def header_title
      return if DataCycleCore.header_title.blank?

      tag.span(DataCycleCore.header_title.is_a?(Proc) ? DataCycleCore.header_title.call : DataCycleCore.header_title, class: 'title')
    end

    def ice_cube_select_options(readonly = false)
      rule_types = [:single_occurrence] + IceCube::Rule::INTERVAL_TYPES.except([:secondly, :minutely, :hourly])
      rule_types.delete(:monthly) unless readonly

      rule_types.map { |r| [t("schedule.#{r}", locale: active_ui_locale), "IceCube::#{r.to_s.classify}Rule", { 'data-type': r }] }
    end

    def display_flash_messages_new(closable: true)
      capture do
        tag.div(class: 'flash-messages') do
          flash.each do |key, value|
            alert_class = DEFAULT_KEY_MATCHING[key.to_sym]
            concat alert_box(value, alert_class, closable)
          end
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
      tag.i(class: "fa #{DATALINK_ICONS[permission]}", aria_hidden: true, data: { dc_tooltip: "<b>#{DataCycleCore::DataLink.human_attribute_name(:permissions, locale: active_ui_locale)}</b>: #{DataCycleCore::DataLink.human_attribute_name("permissions_#{permission}", locale: active_ui_locale)}" })
    end

    def mode_icon(mode, version = nil)
      title = t("view_modes.#{mode}", locale: active_ui_locale)
      title += " (#{version})" if version.present?
      case mode
      when 'grid' then tag.i(class: 'fa fa-th', aria_hidden: true, data: { dc_tooltip: title })
      when 'list' then tag.i(class: 'fa fa-th-list', aria_hidden: true, data: { dc_tooltip: title })
      when 'tree' then tag.i(class: 'fa fa-sitemap', aria_hidden: true, data: { dc_tooltip: title })
      when 'map' then tag.i(class: 'fa fa-map', aria_hidden: true, data: { dc_tooltip: title })
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
              tag.div(class: 'dropdown-pane no-bullet', id: 'tree-view-selector', data: { dropdown: true }) do
                concat(
                  tag.ul(class: 'no-bullet') do
                    DataCycleCore::ClassificationTreeLabel.visible('tree_view').presence&.each do |tree_label|
                      concat(
                        tag.li(
                          link_to_unless(
                            tree_label.id == params_hash[:ctl_id],
                            t("filter.#{tree_label.name.presence&.underscore_blanks}", default: tree_label.name, locale: active_ui_locale),
                            params_hash.except(:ct_id, :con_id, :ctl_id, :cpt_id, :reset)
                              .merge({ mode:, ctl_id: tree_label.id })
                          )
                        )
                      )
                    end
                  end
                )
              end
            )
          elsif DataCycleCore::ClassificationTreeLabel.visible('tree_view').present?
            tree_label = DataCycleCore::ClassificationTreeLabel.visible('tree_view').first
            link_to_unless(
              tree_label.id == params_hash[:ctl_id],
              mode_icon(mode, t("filter.#{tree_label.name.presence&.underscore_blanks}", default: tree_label.name, locale: active_ui_locale)),
              params_hash.except(:ct_id, :con_id, :ctl_id, :cpt_id, :reset)
                .merge({ mode:, ctl_id: tree_label.id })
            )
          end
        end
      else
        link_to_unless selected, mode_icon(mode), params_hash.except(:ct_id, :con_id, :ctl_id, :cpt_id, :reset).merge(mode:)
      end
    end

    def perimeter_search_link(lat, lon)
      return unless lat.present? && lon.present? && can?(:advanced_filter, :backend, '', 'geo_filter', { data: { name: 'geo_radius', advancedType: ' geo_radius' } })

      id_path = "f[#{SecureRandom.hex(10)}]"

      form_tag(root_path) do |_f|
        concat hidden_field_tag("#{id_path}[c]", 'a')
        concat hidden_field_tag("#{id_path}[m]", 'i')
        concat hidden_field_tag("#{id_path}[q]", 'geo_radius')
        concat hidden_field_tag("#{id_path}[t]", 'geo_filter')
        concat hidden_field_tag("#{id_path}[n]", 'geo_radius')
        concat hidden_field_tag("#{id_path}[v][lat]", lat)
        concat hidden_field_tag("#{id_path}[v][lon]", lon)
        concat hidden_field_tag("#{id_path}[v][distance]", 5000)
        concat submit_tag(t('activerecord.attributes.data_cycle_core/place.use_geo_for_perimeter_search', locale: active_ui_locale), class: 'button info')
      end
    end

    def valid_mode(mode)
      case mode
      when 'list', 'tree', 'map' then mode
      else 'grid'
      end
    end

    def dashboard_title
      title = t('data_cycle_core.dashboard', locale: active_ui_locale)

      title << ": #{@stored_filter.name}" if @stored_filter&.name.present?

      title
    end

    # Returns the full title on a per-page basis.
    def full_title
      base_title = I18n.t('title', locale: active_ui_locale) || 'dataCycle'
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
      key.gsub('datahash', 'properties').scan(/\[(.*?)\]/).flatten || []
    end

    def content_view_cache_key(item:, mode:, watch_list:, locale: 'de')
      "#{item.class.name.underscore}_#{item.id}_#{locale}_#{item.updated_at&.to_i}_#{item.cache_valid_since&.to_i}_#{mode}_#{watch_list&.id}_#{active_ui_locale}"
    end

    def new_content_select_options(query_methods: [], content: nil, scope: nil, limit: nil, ordered_array: nil)
      query = DataCycleCore::ThingTemplate.all
      query_methods.presence&.map(&:stringify_keys)&.each do |query_method|
        if query.respond_to?(query_method['method_name']) && query_method.key?('value')
          query = query.try(query_method['method_name'], query_method['value'])
        elsif query.respond_to?(query_method['method_name'])
          query = query.try(query_method['method_name'])
        end
      end

      query = query.template_things.each.select { |t| can?(:create, t, scope, { content: }) }
      if ordered_array.present?
        query = query.sort_by { |t| ordered_array.index(t.template_name).to_i }
      else
        query = query.sort_by(&:template_name)
      end
      query = query.first(limit.to_i) if limit.present?

      query
    end

    def to_query_params(options_hash)
      params_hash = {}

      return params_hash if options_hash.blank?

      options_hash.each do |key, value|
        if value.is_a?(DataCycleCore::Thing) && !value.persisted?
          params_hash[key] = value.thing_template.persisted? ? { class: value.class.name, attributes: value.attributes.merge(value.attr_accessor_attributes) } : { class: value.class.name, attributes: value.attributes.merge(value.attr_accessor_attributes).merge(thing_template: { class: value.thing_template.class.name, attributes: value.thing_template.attributes }) }
        elsif value.is_a?(ActiveRecord::Base)
          params_hash[key] = value.persisted? ? { value.class.primary_key.to_sym => value.try(value.class.primary_key), class: value.class.name } : { class: value.class.name, attributes: value.attributes }
        elsif value.is_a?(ActiveRecord::Relation)
          params_hash[key] = { class: value.klass.name, value.klass.primary_key.to_sym => value.pluck(value.klass.primary_key), type: 'Collection' }
        elsif value.is_a?(OpenStruct)
          params_hash[key] = { attributes: value.to_h, class: 'OpenStruct' }
        elsif value.is_a?(::Hash)
          params_hash[key] = to_query_params(value)
        else
          params_hash[key] = value
        end
      end

      params_hash
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
      end.transform_values do |v|
        v&.map { |t|
          key = Array.wrap(t).first

          next unless key.include?(filter.to_s)
          next if Array.wrap(except).include?(key)

          if t.is_a?(::Array)
            t[0] = t[0]&.remove('**list')&.squish
            t
          else
            t&.remove('**list')&.squish
          end
        }&.compact
      end
    end

    def content_uploader_data_hash(content, asset)
      return {} if asset.nil?

      asset_key = content&.asset_property_names&.first

      return {} if asset_key.nil?

      content.set_memoized_attribute(asset_key, asset)

      { asset_key => asset.id }.with_indifferent_access
    end

    def attribute_label_for_uploader(key, value)
      return value['properties']&.map { |k, v| attribute_label_for_uploader(k, v) }&.reduce({}, :merge) if value['type'] == 'object'

      { key => value.slice('type', 'label', 'ui').merge({ default_value: value.key?('default_value') }) }
    end

    def new_attribute_labels(template)
      template
        &.schema
        &.[]('properties')
        &.slice(*new_dialog_config(template, nil, '**list').values.flatten)
        &.map { |key, value| attribute_label_for_uploader(key, value) }
        &.reduce({}, :merge)
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

      templates = DataCycleCore::ThingTemplate
        .select("DISTINCT ON (thing_templates.template_name, asset_type) *, property_name.value ->> 'asset_type' AS asset_type")
        .from("thing_templates, jsonb_each(schema -> 'properties') property_name")
        .where(
          "(property_name.value ->> 'asset_type' = ? OR thing_templates.template_name IN (?))",
          asset_type,
          DataCycleCore.features.dig(:external_media_archive, :enabled) ? DataCycleCore::Feature::ExternalMediaArchive.get_template_name(asset_type) : nil
        ).template_things

      creatable = false
      templates.each do |t|
        creatable ||= (t.content_type?('embedded') ? t.parent_templates&.any? { |pt| can?(:create, pt, 'asset') } : can?(:create, t, 'asset'))
      end

      uploader_model = "data_cycle_core/#{asset_type}".classify.safe_constantize

      return {} unless creatable && uploader_model

      {
        format: uploader_model.extension_white_list,
        class: uploader_model.name,
        translation: uploader_model.model_name.human(count: 1, locale: active_ui_locale),
        translation_description: t("uploader.description.#{uploader_model.name.demodulize.underscore}", locale: active_ui_locale, default: '')
      }.with_indifferent_access.merge(DataCycleCore.uploader_validations[uploader_model.name.demodulize.underscore.to_sym] || {})
    end

    def render_content_partial(partial, parameters)
      raise "try to render content_partial that is not a thing: #{partial} || #{parameters}" unless ['data_cycle_core/thing', 'data_cycle_core/thing/history'].include?(parameters[:content].class.name.underscore)

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

    def render_linked_viewer(key:, definition:, value:, parameters: {}, content: nil)
      partials = [
        key.attribute_name_from_key,
        definition&.dig('template_name')&.underscore_blanks,
        'thing',
        'default'
      ].reject(&:blank?).map { |p| "data_cycle_core/contents/viewers/linked/#{p}" }

      render_first_existing_partial(partials, parameters.merge({ key:, definition:, value:, content: }))
    end

    def render_linked_history_viewer(key:, definition:, value:, parameters: {}, content: nil)
      partials = [
        key.attribute_name_from_key,
        definition&.dig('ui', 'show', 'type')&.underscore_blanks,
        definition.dig('template_name')&.underscore_blanks,
        'thing',
        'default'
      ].reject(&:blank?).map { |p| "data_cycle_core/contents/history/linked/#{p}" }

      render_first_existing_partial(partials, parameters.merge({ key:, definition:, value:, content: }))
    end

    def render_asset_editor(key:, value:, definition:, parameters: {}, content: nil)
      partials = [
        definition.dig('asset_type')&.underscore_blanks,
        'default'
      ].reject(&:blank?).map { |p| "data_cycle_core/contents/editors/asset/#{p}" }
      render_first_existing_partial(partials, parameters.merge({ key:, definition:, value:, content: }))
    end

    def render_asset_viewer(key:, value:, definition:, parameters: {}, content: nil)
      value = value.first if value.is_a?(ActiveRecord::Relation) || value.is_a?(Array)
      partials = [
        value.try(:type)&.demodulize&.underscore_blanks,
        'default'
      ].reject(&:blank?).map { |p| "data_cycle_core/contents/viewers/asset/#{p}" }
      render_first_existing_partial(partials, parameters.merge({ key:, definition:, value:, content: }))
    end

    def render_content_tile(item:, parameters: {}, mode: 'grid')
      partials = [
        item.try(:template_name)&.underscore_blanks,
        item.try(:schema_type)&.underscore_blanks,
        item.try(:content_type)&.underscore_blanks,
        item&.class&.name&.demodulize&.underscore_blanks,
        'default'
      ].reject(&:blank?).map { |p| "data_cycle_core/contents/#{mode}/#{p}" }

      render_first_existing_partial(partials, parameters.merge({ item: }))
    end

    def render_content_tile_details(item:, parameters: {}, mode: 'grid')
      partials = [
        item.try(:template_name)&.underscore_blanks,
        item.try(:schema_type)&.underscore_blanks,
        item.try(:content_type)&.underscore_blanks,
        item&.class&.name&.demodulize&.underscore_blanks,
        'default'
      ].reject(&:blank?).map { |p| "data_cycle_core/contents/#{mode}/#{p}_details" }

      render_first_existing_partial(partials, parameters.merge({ item: }))
    end

    def render_linked_partial(key:, definition:, parameters: {}, content: nil)
      partials = [
        definition.dig('template_name')&.underscore_blanks,
        parameters&.dig(:object)&.try(:schema_type)&.underscore_blanks,
        'default'
      ].reject(&:blank?).map { |p| "data_cycle_core/contents/grid/compact/#{p}" }
      render_first_existing_partial(partials, parameters.merge({ key:, definition:, content: }))
    end

    def render_linked_details(key:, definition:, parameters: {}, content: nil)
      partials = [
        definition.dig('template_name')&.underscore_blanks,
        parameters&.dig(:object)&.try(:schema_type)&.underscore_blanks,
        'default'
      ].reject(&:blank?).map { |p| "data_cycle_core/contents/editors/object_browser/#{p}_detail" }
      render_first_existing_partial(partials, parameters.merge({ key:, definition:, content: }))
    end

    def render_embedded_object_partial(key:, definition:, parameters: {}, content: nil)
      partials = [
        "#{definition['type'].underscore_blanks}_#{key.attribute_name_from_key}",
        definition&.dig('ui', 'edit', 'embedded_partial').presence,
        definition['type'].underscore_blanks.to_s,
        'default'
      ].compact.map { |p| "data_cycle_core/contents/editors/embedded/#{p}" }

      render_first_existing_partial(partials, parameters.merge({ key:, definition:, content: }))
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

      render_first_existing_partial(partials, parameters.merge({ template: }))
    end

    def link_to_condition(condition, name, options = {}, html_options = {}, &block)
      if condition
        link_to(name, options, html_options, &block)
      elsif block
        block.arity <= 1 ? capture(name, &block) : capture(name, options, html_options, &block)
      else
        ERB::Util.html_escape(name)
      end
    end

    def conditional_tag(name, condition, options = nil, &)
      if condition
        content_tag name, capture(&), options
      else
        capture(&)
      end
    end

    def validation_messages(content, key)
      messages_html = ActionView::OutputBuffer.new

      if content.errors.present?
        messages_html << tag.b(t('frontend.validate.error', locale: active_ui_locale), class: 'error-tooltip-title')
        messages_html << tag.br
        messages_html << safe_join(content.errors.messages[key.attribute_name_from_key.to_sym]&.map { |em| tag.span(em, class: 'alert') }, tag.br)
      end

      if content.warnings.present?
        messages_html << tag.b(t('frontend.validate.warning', locale: active_ui_locale), class: 'warning-tooltip-title')
        messages_html << tag.br
        messages_html << safe_join(content.warnings.messages[key.attribute_name_from_key.to_sym]&.map { |em| tag.span(em, class: 'warning') }, tag.br)
      end

      messages_html
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
      options = { class: 'new-notification', data: {}, style: 'display: none;' }
      options[:data][:closable] = '' if closable
      options[:data][:type] = alert_class
      options[:data][:id] = SecureRandom.hex(10)

      if value.is_a?(::String)
        options[:data][:text] = value
      elsif value.is_a?(::Hash) || value.is_a?(ActiveModel::DeprecationHandlingMessageHash)
        options[:data][:text] = value.map { |k, v| "#{k.to_s.titleize}: #{v.join(', ')}" }.join('<br>')
      elsif value.is_a?(::Array)
        options[:data][:text] = value.join('<br>')
      else
        options[:data][:text] = value.to_s
      end

      tag.div(**options)
    end

    def yield_content!(content_key)
      view_flow.content.delete(content_key)
    end
  end
end
