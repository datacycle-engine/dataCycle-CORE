# frozen_string_literal: true

class ImportHelper
  class << self
    # Check if external source exists and has an import config
    # @param external_source_name [String]
    # @param type [Array<String>] optional array of 'download' or 'import' to check for specific config. If nil, both are checked
    # @return [DataCycleCore::ExternalSystem]
    def external_system(external_source_name, type = ['download', 'import'])
      external_source = DataCycleCore::ExternalSystem.by_names_identifiers_or_ids(external_source_name)
      abort("External source not found: #{external_source_name}") if external_source.nil?
      abort("Ambiguous external source: #{external_source_name}") if external_source.many?
      external_source = external_source.first
      abort("No import config found for external source: #{external_source_name}") if external_source.import_config.blank? && (type.blank? || type.include?('import'))
      abort("No download config found for external source: #{external_source_name}") if external_source.download_config.blank? && (type.blank? || type.include?('download'))
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
  end
end
