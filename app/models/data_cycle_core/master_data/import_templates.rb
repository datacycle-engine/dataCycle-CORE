module DataCycleCore
  module MasterData
    class ImportTemplates

      def import(directory, object)
        begin
          Dir.chdir(directory)
          file_names = Dir.entries("./")
          file_names.delete(".")
          file_names.delete("..")
          file_names.each do |filename|
            data_templates = YAML.load(File.open(filename.to_s))
            iterate_templates(data_templates, object)
          end
        rescue Exception => e
          puts "could not access a YML File in directory #{directory}"
          puts e.message
          puts e.backtrace
        end
      end

      def iterate_templates(data_templates, object)
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
