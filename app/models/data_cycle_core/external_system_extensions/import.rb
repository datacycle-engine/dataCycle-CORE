# frozen_string_literal: true

module DataCycleCore
  module ExternalSystemExtensions
    module Import
      def sorted_step_config_by_type(type)
        sorted_steps(type.to_sym).map do |k|
          config = send(:"#{type}_config")[k]
          config.merge('name' => k, 'type' => step_type(config))
        end
      end

      def sorted_step_configs
        steps = []
        steps.concat(sorted_step_config_by_type(:download))
        steps.concat(sorted_step_config_by_type(:import))
        steps
      end

      def relevant_steps_for(source_type, type = nil)
        sorted_step_configs.filter do |step|
          (type.nil? || type == step['type']) &&
            Array.wrap(step['source_type']).include?(source_type)
        end
      end

      def source_steps_successful?(source_type, type)
        relevant_steps_for(source_type, type).all? do |step|
          last_successful_try(step['name'], step['type'])
            &.>=(last_try(step['name'], step['type']))
        end
      end

      def sorted_steps(type = :import, range = nil)
        steps = send(:"#{type}_config")
        return [] if steps.blank?

        steps = steps.filter { |_, v| v['depends_on'].blank? }
        steps = steps.filter { |_, v| v['sorting'].in?(range) } if range.present?

        steps.sort_by { |_, v| v['sorting'] }.pluck(0)
      end

      def download(options = {}, &)
        raise 'First parameter has to be an options hash!' unless options.is_a?(::Hash)

        success = true
        ts_start = Time.zone.now
        skip_save = options.delete(:skip_save)

        self.last_download = ts_start
        save if skip_save.blank?

        sorted_steps(:download).each do |name|
          success &&= download_single(name, options, &)
        end

        ts_after = Time.zone.now
        self.last_download_time = ts_after - ts_start

        if success
          self.last_successful_download = ts_start
          self.last_successful_download_time = ts_after - ts_start
        end

        save if skip_save.blank?
        success
      end

      def download_range(options = {}, &)
        raise 'First parameter has to be an options hash!' unless options.is_a?(::Hash)

        success = true
        min = options[:min] || 0
        max = options[:max] || Float::INFINITY

        sorted_steps(:download, min..max).each do |name|
          success &&= download_single(name, options, &)
        end

        success
      end

      def timestamp_key_for_step(name, type = nil)
        config = if type.present?
                   send(:"#{type}_config")[name]
                 else
                   download_config[name] || import_config[name]
                 end
        raise "unknown step: #{name}" if config.blank?

        "#{config.key?('import_strategy') ? 'i_' : 'd_'}#{name}"
      end

      def sorted_step_times
        sorted_times = []

        sorted_steps(:download).each do |name|
          key = timestamp_key_for_step(name, :download)
          data = last_import_step_time_info[key]
          next if data.blank?

          sorted_times << data.merge('name' => name, 'key' => key)
        end

        sorted_steps(:import).each do |name|
          key = timestamp_key_for_step(name, :import)
          data = last_import_step_time_info[key]
          next if data.blank?

          sorted_times << data.merge('name' => name, 'key' => key)
        end

        sorted_times
      end

      def download_single(name, options = {})
        config = download_config[name]
        raise "unknown downloader name: #{name}" if config.blank?

        import_step(name, options, config)
      end
      alias single_download download_single

      def import(options = {}, &)
        raise 'First parameter has to be an options Hash!' unless options.is_a?(::Hash)

        ts_start = Time.zone.now
        update_columns(last_import: ts_start)

        sorted_steps(:import).each do |name|
          update_columns(last_import_time: Time.zone.now - ts_start)
          import_single(name, options, &)
          update_columns(last_import_time: Time.zone.now - ts_start)
        end

        update_columns(
          last_successful_import: ts_start,
          last_successful_import_time: Time.zone.now - ts_start
        )
      end

      def import_range(options = {}, &)
        raise 'First parameter has to be an options Hash!' unless options.is_a?(::Hash)

        min = options[:min] || 0
        max = options[:max] || Float::INFINITY

        sorted_steps(:import, min..max).each do |name|
          import_single(name, options, &)
        end
      end

      def import_single(name, options = {})
        config = import_config[name]
        raise "unknown importer name: #{name}" if config.blank?

        import_step(name, options, config)
      end
      alias single_import import_single

      def options_for_step(name, options = {}, config = {}, type = :import)
        step_options = (default_options(type)&.dc_deep_dup || {}).deep_symbolize_keys
        step_options.deep_merge!(
          type.to_sym => config.deep_symbolize_keys
                               .except(:sorting)
                               .merge({ name: name.to_s })
        )
        step_options.deep_merge!(options.deep_symbolize_keys)

        add_locales_for_step!(step_options, type)
        add_credentials_for_step!(step_options) if type == :download

        step_options
      end

      def add_locales_for_step!(options, type)
        options[:locales] = options.dig(type, :locales) ||
                            options[:locales] ||
                            I18n.available_locales
      end

      def add_credentials_for_step!(options)
        return if options.key?(:credentials)

        creds = Array.wrap(credentials || {})
        credential_key = options[:credential_key]

        if credential_key.present? && options[:credentials_index].blank?
          credentials_index = creds.index { |item| item['credential_key'] == credential_key }
          raise "Error: credential not found for key: #{credential_key}!" if credentials_index.nil?
          options[:credentials_index] = credentials_index
        end

        creds = Array.wrap(creds[options[:credentials_index]]) if options[:credentials_index].present?

        options[:credentials] = creds
      end

      def utility_object_for_step(type, options = {})
        "data_cycle_core/generic/#{type}_object".classify.safe_constantize.new(
          external_source: self,
          **options
        )
      end

      def step_type(step_config)
        step_config.key?('import_strategy') ? :import : :download
      end

      def import_step(name, options = {}, config = {})
        raise "missing config for name: #{name}" if config.blank?
        last_start = Time.zone.now
        type = step_type(config)
        full_options = options_for_step(name, options, config, type)
        strategy = full_options.dig(type, :"#{type}_strategy")&.safe_constantize
        raise "Missing strategy for #{name}, options given: #{full_options}" if strategy.nil?

        json_key = timestamp_key_for_step(name, type)
        strategy_method = strategy.respond_to?(:import_data) ? :import_data : :download_content
        utility_object = utility_object_for_step(type, full_options)

        merge_last_import_step_time_info(json_key, {last_try: last_start})
        update_columns(last_import_step_time_info: last_import_step_time_info)

        strategy.send(strategy_method, utility_object:, options: full_options)
        success = true
      rescue StandardError
        success = false
        raise
      ensure
        duration = Time.zone.now - last_start
        update_info = {
          last_try_time: duration
        }
        if success
          update_info = update_info.merge({
            last_successful_try: last_start,
            last_successful_try_time: duration
          })
        end

        merge_last_import_step_time_info(json_key, update_info)
        update_columns(last_import_step_time_info: last_import_step_time_info)
      end

      def import_one(name, external_key, options = {}, mode = 'full')
        raise 'no external key given' if external_key.blank?
        import_single(name, options.deep_merge({ mode:, import: { source_filter: { external_id: external_key } } }))
      end
    end
  end
end
