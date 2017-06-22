module DataCycleCore
  module MasterData
    class ImportTemplates

      def import(filename, object)
        begin
          data_templates = YAML.load(File.open(filename.to_s))
          iterate_templates(data_templates, object)
        rescue Exception => e
          puts "could not access the file: #{filename}"
          puts e.message
          puts e.backtrace
        end
      end

      def iterate_templates(data_templates)
        data_templates.each do |template|
          data_set = object
            .find_or_initialize_by(
              headline: template[:data][:name],
              description: template[:data][:description],
              template: true
            )
          data_set.seen_at = Time.zone.now
          if data_set.metadata.blank?
            data_set.metadata = {validation: template[:data]}
          else
            data_set.metadata[:validation] = template[:data]
          end
          data_set.save
        end
      end

    end
  end
end
