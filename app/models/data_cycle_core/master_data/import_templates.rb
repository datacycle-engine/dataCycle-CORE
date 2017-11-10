module DataCycleCore
  module MasterData
    class ImportTemplates

      def import(files, object)
        begin
          file_names = Dir[files]
          file_names.each do |filename|
            data_templates = YAML.load(File.open(filename.to_s))
            iterate_templates(data_templates, object)
          end
        rescue Exception => e
          puts "could not access a YML File in directory #{files}"
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

      def validator
        Dry::Validation.Schema do
          required(:data).schema do
            required(:name) {str?}
            required(:description) { str? & included_in?(DataCycleCore.content_tables.map(&:classify)) }
            required(:type) { str? & eql?('object') }

            optional(:content_type) { str? & included_in?(['variant', 'embedded', 'entity']) }
            optional(:releasable) { bool? }
            optional(:permissions) do
              schema do
                required(:read_write) { bool? }
              end
            end
            optional(:boost) { float? }

            required(:properties).schema do

            end

          end
        end
      end

      def attribute_validation
      end 
    end
  end
end
