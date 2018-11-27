# frozen_string_literal: true

module DataCycleCore
  module Export
    module TextFile
      module Create
        def self.process(data)
          output_file = DataCycleCore::Generic::Logger::LogFile.new('my_super_log')
          output_file.preparing_phase('Create Item')
          output_file.info(data.name, data.id)
          output_file.close if output_file.respond_to?(:close)
        end

        def self.filter(data)
          ['Artikel'].include?(data.template_name)
        end
      end
    end
  end
end
