# frozen_string_literal: true

module DataCycleCore
  module ExternalSystemExtensions
    module Import
      def sorted_steps(type = :import, range = nil)
        steps = send("#{type}_config")
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
        min = options.dig(:min) || 0
        max = options.dig(:max) || Float::INFINITY

        sorted_steps(:download, (min..max)).each do |name|
          success &&= download_single(name, options, &)
        end

        success
      end

      def download_single(name, options = {})
        config = download_config.dig(name)
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

        min = options.dig(:min) || 0
        max = options.dig(:max) || Float::INFINITY

        sorted_steps(:import, (min..max)).each do |name|
          import_single(name, options, &)
        end
      end

      def import_single(name, options = {})
        config = import_config.dig(name)
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
        step_options[:locales] = step_options.dig(:import, :locales) ||
                                 step_options[:locales] ||
                                 I18n.available_locales

        step_options
      end

      def utility_object_for_step(type, options = {}, additional_options = {})
        "data_cycle_core/generic/#{type}_object".classify.safe_constantize.new(
          external_source: self,
          **options,
          **additional_options
        )
      end

      def import_step(name, options = {}, config = {})
        raise "missing config for name: #{name}" if config.blank?

        success = true
        type = config.key?('import_strategy') ? :import : :download
        full_options = options_for_step(name, options, config, type)
        strategy = full_options.dig(type, :"#{type}_strategy")&.safe_constantize
        strategy_method = strategy.respond_to?(:import_data) ? :import_data : :download_content
        additional_options = {}
        raise "Missing strategy for #{name}, options given: #{options}" if strategy.nil?

        if type == :download && strategy.respond_to?(:credentials?) && !strategy.credentials?
          additional_options = { credentials: {} }
        elsif type == :download
          cred = Array.wrap(credentials || {})
          cred = Array.wrap(cred[full_options[:credentials_index]]) if full_options[:credentials_index].present?
          additional_options = cred.map { |credential| { credentials: credential } }
        end

        Array.wrap(additional_options).each do |add_option|
          utility_object = utility_object_for_step(type, full_options, add_option)
          success &&= strategy.send(strategy_method, utility_object:, options: full_options)
        end

        success
      end

      def import_one(name, external_key, options = {}, mode = 'full')
        raise 'no external key given' if external_key.blank?
        import_single(name, options.deep_merge({ mode:, import: { source_filter: { external_id: external_key } } }))
      end
    end
  end
end
