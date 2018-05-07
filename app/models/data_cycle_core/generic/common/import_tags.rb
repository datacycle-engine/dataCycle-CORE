module DataCycleCore
  module Generic
    module Common
      module ImportTags
        def import_data(**options)
          raise 'Missing configuration attribute "tree_label"' if options.dig(:import, :tree_label).blank?
          raise 'Missing configuration attribute "tag_id_path"' if options.dig(:import, :tag_id_path).blank?
          raise 'Missing configuration attribute "tag_name_path"' if options.dig(:import, :tag_name_path).blank?

          import_classifications(
            @source_type,
            options.dig(:import, :tree_label),
            method(:load_root_classifications).to_proc,
            ->(_, _, _) { [] },
            ->(_) { nil },
            method(:extract_data).to_proc,
            **options
          )
        end

        protected

        def load_root_classifications(mongo_item, locale)
          common_tag_path = @options.dig(:import, :tag_id_path).split('.')
            .zip(@options.dig(:import, :tag_name_path).split('.'))
            .take_while { |id_component, name_component| id_component == name_component }
            .map(&:first)
            .join('.')

          mongo_item.collection.aggregate(mongo_item.where(:_id.ne => nil)
            .unwind(
              "dump.#{locale}.#{common_tag_path}"
            ).project(
              "dump.#{locale}.id": "$dump.#{locale}.#{@options.dig(:import, :tag_id_path)}",
              "dump.#{locale}.tag": "$dump.#{locale}.#{@options.dig(:import, :tag_name_path)}"
            ).group(
              _id: "$dump.#{locale}.id",
              :dump.first => '$dump'
            ).pipeline)
        end

        def extract_data(raw_data)
          external_id = case @options.dig(:import, :external_id_hash_method)
                        when 'MD5'
                          Digest::MD5.new.update(raw_data['id']).hexdigest
                        else
                          raw_data['id']
                        end

          {
            external_id: "#{@options.dig(:import, :external_id_prefix)}#{external_id}",
            name: raw_data['tag']
          }
        end
      end
    end
  end
end
