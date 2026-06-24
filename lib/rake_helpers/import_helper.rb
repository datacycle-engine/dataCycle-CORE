# frozen_string_literal: true

class ImportHelper
  class << self
    # Check if external source exists and has an import config
    # @param external_source_name [String]
    # @param type [Array<String>] optional array of 'download' or 'import' to check for specific config. If nil, both are checked
    # @return [DataCycleCore::ExternalSystem]
    def external_system(external_source_name, type = ['download', 'import'])
      external_source = DataCycleCore::ExternalSystem.by_names_identifiers_or_ids(external_source_name)
      raise "External source not found: #{external_source_name}" if external_source.nil?
      raise "Ambiguous external source: #{external_source_name}" if external_source.many?

      external_source = external_source.first
      raise "No import config found for external source: #{external_source_name}" if external_source.import_config.blank? && (type.blank? || type.include?('import'))
      raise "No download config found for external source: #{external_source_name}" if external_source.download_config.blank? && (type.blank? || type.include?('download'))

      external_source
    end

    def perform_job(external_source, mode, run_now, job_class)
      job = job_class.new(external_source.id, mode)
      run_now = ['true', true].include?(run_now)
      if Delayed::Job.exists?(queue: job.queue_name, delayed_reference_type: job.delayed_reference_type, delayed_reference_id: job.delayed_reference_id, locked_at: nil, failed_at: nil)
        # do nothing
      elsif run_now
        job.perform_now
      else
        job.enqueue
      end
    end

    def legacy_task(key, *)
      Rake::Task["data_cycle_core:import:#{key}"].invoke(*)
      Rake::Task["data_cycle_core:import:#{key}"].reenable
    end

    def convert_args_to_options(args)
      number_args = [:max_count, :min_count]
      {}.merge(args.to_h).to_h do |k, v|
        if number_args.include?(k)
          [k, v.to_i]
        else
          [k, v]
        end
      end
    end

    def import_by_cred(args)
      options = convert_args_to_options(args)
      raise 'Error: credential_key is required!' if options[:credential_key].nil?

      options[:import] ||= {}

      # not all collection have the external_system field. We want to import this data as well.
      options[:import][:source_filter] = {
        'external_system.credential_keys' => { '$in' => [nil, options[:credential_key]] }
      }

      external_source = DataCycleCore::ExternalSystem.by_names_identifiers_or_ids(options[:external_source_id]).first

      options[:import_names] = external_source.config['import_config'].sort_by { |_, config| config['sorting'] }.to_h.keys.join('|') if options[:import_names].nil?
      options[:import_names].presence.split('|').each do |import_name|
        external_source.import_single(import_name.squish.to_sym, options)
      end
    end

    def download_by_cred(args)
      options = convert_args_to_options(args)
      raise 'Error: credential_key is required!' if options[:credential_key].nil?

      external_source = DataCycleCore::ExternalSystem.by_names_identifiers_or_ids(options[:external_source_id]).first

      raise 'External source not found!' if external_source.nil?

      options[:skip_save] = true

      if options[:download_names].present?
        options[:download_names].split('|').each do |download_name|
          external_source.download_single(download_name.squish.to_sym, options)
        end
      else
        external_source.download(options)
      end
    end
  end
end
