# frozen_string_literal: true

module DataCycleCore
  module ExternalSystemHelper
    def external_systems_tooltip(external_source, external_system_syncs)
      syncs = external_system_syncs
        &.group_by { |sync| sync.external_system.name }
        &.transform_values(&:size) || {}

      unless external_source.nil?
        syncs[external_source.name] = syncs[external_source.name].to_i + 1
        syncs = { "#{external_source.name} *" => syncs.delete(external_source.name) }.merge!(syncs)
      end

      syncs.map { |k, v| v > 1 ? "#{k} (#{v})" : k }.join('<br>')
    end

    def external_systems_with_details(content)
      syncs = {}

      unless content.external_source.nil?
        syncs[content.external_source] = {}
        syncs[content.external_source]['meta'] = {}
        syncs[content.external_source]['meta']['status'] = ['success']
        syncs[content.external_source]['meta']['count'] = 1
        syncs[content.external_source]['meta']['primary'] = true
        syncs[content.external_source]['import'] = [{
          status: 'success',
          sync_type: 'import',
          primary: true,
          date: [content.updated_at, content.external_source.last_successful_import].compact.min,
          external_key: content.external_key || content.id,
          external_detail_url: content.external_source.external_detail_url(content),
          external_edit_url: content.external_source.external_url(content),
          title: "#{DataCycleCore::ExternalSystemSync.human_attribute_name(:external_key, locale: active_ui_locale)}: #{content.external_key || content.id}",
          external_system_id: content.external_source.id
        }]
      end

      content.external_system_syncs.includes(:external_system).find_each do |sync|
        syncs[sync.external_system] ||= {}
        syncs[sync.external_system][sync.sync_type] ||= []
        syncs[sync.external_system]['meta'] ||= {}
        syncs[sync.external_system]['meta']['count'] ||= 0
        syncs[sync.external_system]['meta']['count'] += 1
        syncs[sync.external_system]['meta']['status'] ||= []
        syncs[sync.external_system]['meta']['status'] << sync.status if sync.status.present?
        syncs[sync.external_system][sync.sync_type] << {
          id: sync.id,
          external_system_id: sync.external_system.id,
          status: sync.status,
          sync_type: sync.sync_type,
          date: sync.last_sync_at,
          successful_date: sync.last_successful_sync_at,
          external_key: sync.external_key || content.id,
          external_edit_url: sync.external_url,
          external_detail_url: sync.external_detail_url,
          sync_locale: sync.data&.dig('pull_data', 'inLanguage')&.upcase,
          name: sync.data&.dig('name').present? ? [sync.data.dig('pull_data', 'inLanguage')&.upcase, sync.data['name']].compact.join(': ') : nil,
          title: [
            sync.data&.dig('name').present? ? "#{t('common.external_name', locale: active_ui_locale)}: #{sync.data['name']}" : nil,
            sync.data&.dig('alternate_name').present? ? "#{t('common.external_alternate_name', locale: active_ui_locale)}: #{sync.data['alternate_name']}" : nil,
            sync.data&.dig('pull_data', 'inLanguage').present? ? "#{t('common.external_locale', locale: active_ui_locale)}: #{t("locales.#{sync.data.dig('pull_data', 'inLanguage')}", locale: active_ui_locale)}" : nil,
            "#{t('common.external_key', locale: active_ui_locale)}: #{sync.external_key || content.id}"
          ].compact.join("\n\n")
        }
      end

      syncs.each_value do |v|
        v['meta']['status'].uniq!
        v.except('meta').each_value do |sync_list|
          sync_list.sort_by! { |s| s[:name] || s[:external_key] }
        end
      end
    end

    def external_sync_status_icon(status, sync_type, include_status_message = false)
      additional_classes = "external-system-icon #{status}"
      icon = case sync_type
             when 'import', 'export'
               tag.span(
                 tag.i(class: 'fa fa-file-o') +
                 tag.i(class: 'fa fa-long-arrow-right'),
                 class: "fa-stack #{sync_type} #{additional_classes}"
               )
             when 'duplicate'
               tag.i(class: "fa fa-clone #{additional_classes}")
             else tag.i(class: "fa fa-link #{additional_classes}")
             end

      icon = tag.i(class: "fa fa-refresh #{additional_classes}") if status == 'pending'
      icon = tag.i(class: "fa fa-times #{additional_classes}") if status&.in?(['failure', 'error'])

      return icon unless include_status_message

      messages = []
      messages << "<b>#{t('common.status', locale: active_ui_locale)}</b>: #{t("external_connection_states.#{status}", locale: active_ui_locale)}" if status.present?
      messages << "<b>#{t('external_connections.type', locale: active_ui_locale)}</b>: #{t("common.#{sync_type}", locale: active_ui_locale)}"

      tag.span(icon, data: { dc_tooltip: messages.join('<br>') })
    end

    def external_system_template_paths
      DataCycleCore.external_system_template_paths.index_by { |k| File.basename(k, '.yml.erb') }
    end

    def external_system_template_options
      external_system_identifiers = DataCycleCore::ExternalSystem.pluck(:identifier)
      external_system_template_paths.select { |_k, v|
        data = YAML.safe_load(File.open(v), permitted_classes: [Symbol])
        data['identifier'] ||= data['name']

        external_system_identifiers.exclude?(data['identifier'])
      }.keys
    end

    def last_step_status(data)
      return 'unkown' unless data['last_try'].present? || data['last_successful_try'].present?

      return data['status'] if data['status'].present?
      return 'finished' if data['last_try'] == data['last_successful_try']
      return 'running' if data['last_try'].present? && data['last_successful_try'].present? && data['last_try'] > data['last_successful_try']

      'error'
    end

    def last_step_icon(key)
      icon_class = if key&.start_with?('d_')
                     'fa-long-arrow-down'
                   elsif key&.start_with?('i_')
                     'fa-long-arrow-right'
                   else
                     'fa-circle'
                   end

      tag.i(class: "fa #{icon_class} step-type-icon")
    end

    def last_step_duration(duration, last_status = nil)
      if last_status != 'finished' || duration.blank?
        icon_class = case last_status
                     when 'running'
                       'fa-spinner fa-spin'
                     when 'error'
                       'fa-times'
                     else
                       'fa-circle'
                     end

        return tag.i(class: "fa #{icon_class} step-duration-icon")
      end

      duration = duration.to_f
      duration_unit = 's'
      duration_size = 'duration-s'

      if duration > 60
        duration /= 60
        duration_unit = 'm'
        duration_size = duration >= 30 ? 'duration-l' : 'duration-m'
      end

      if duration > 60
        duration /= 60
        duration_unit = 'h'
        duration_size = 'duration-xl'
      end

      tag.span("#{duration.round}#{duration_unit}", class: duration_size)
    end

    def last_step_tooltip(data, last_status = nil)
      last_try = data['last_try']
      last_try_time = data['last_try_time']
      last_successful_try = data['last_successful_try']
      last_successful_try_time = data['last_successful_try_time']

      return if last_try.blank?

      capture do
        concat(tag.b("#{t('import_steps.last_try', locale: active_ui_locale)}: "))
        concat(import_data_time(Time.zone.parse(last_try)))
        concat(" (#{distance_of_time_in_words(Time.zone.now, Time.zone.now + last_try_time, locale: active_ui_locale)})") if last_try_time.present? && last_status != 'running'
        concat(' (<i class="fa fa-spinner fa-spin"></i>)') if last_status == 'running'

        if last_successful_try.present? && last_successful_try != last_try
          concat(tag.br)
          concat(tag.b("#{t('import_steps.last_successful_try', locale: active_ui_locale)}: "))
          concat(import_data_time(Time.zone.parse(last_successful_try)))
          concat(" (#{distance_of_time_in_words(Time.zone.now, Time.zone.now + last_successful_try_time, locale: active_ui_locale)})") if last_successful_try_time.present?
        end
      end
    end
  end
end
