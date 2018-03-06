module DataCycleCore
  module MasterData
    module ImportTemplates
      def self.import_all(validation: true)
        template_paths = [DataCycleCore.default_template_paths, DataCycleCore.template_path].flatten.uniq.compact
        import_hash, duplicates = check_for_duplicates(template_paths)
        errors = import_all_templates(template_hash: import_hash, validation: validation)
        return errors.reject { |_, value| value.blank? }.map { |key, value| { key => value.deep_dup } }.inject(&:merge) || {}, duplicates || {}
      end

      def self.check_for_duplicates(template_paths)
        import_list = {}
        collisions = {}
        DataCycleCore.content_tables.each do |content_table_name|
          import_list[content_table_name.to_sym] = []
          collisions[content_table_name.to_sym] = {}
        end

        template_paths.each do |core_template_path|
          DataCycleCore.content_tables.each do |content_table_name|
            files = core_template_path + content_table_name + '*.yml'
            file_names = Dir[files]
            file_names.each do |file_name|
              data_templates = YAML.load(File.open(file_name.to_s))
              new_template_definitions = data_templates.map { |item| item[:data][:name] }
              data_templates.each_index do |index|
                already_exist_index = import_list[content_table_name.to_sym].index { |item| item[:name] == data_templates[index][:data][:name] }
                new_template_data = { name: data_templates[index][:data][:name], file: file_name, position: index }
                if already_exist_index.nil?
                  import_list[content_table_name.to_sym] += [new_template_data]
                else
                  if collisions[content_table_name.to_sym][new_template_data[:name]].blank?
                    collisions[content_table_name.to_sym] = collisions[content_table_name.to_sym].merge({ new_template_data[:name] => [import_list[content_table_name.to_sym][already_exist_index].except(:name)] })
                  end
                  collisions[content_table_name.to_sym][new_template_data[:name]] += [{ file: file_name, position: index }]
                  import_list[content_table_name.to_sym][already_exist_index] = new_template_data
                end
              end
            end
          end
        end
        return import_list, collisions.reject { |_, value| value.blank? }.map { |key, value| { key => value.dup } }.inject(&:merge)
      rescue StandardError => e
        puts "could not access a YML File in directory #{core_template_path}, file #{file_name}"
        puts e.message
        puts e.backtrace
      end

      def self.import_all_templates(template_hash:, validation: true)
        errors = {}
        template_hash.each do |content_table, template_list|
          content_object = "DataCycleCore::#{content_table.to_s.classify}".constantize
          errors = errors.merge({ content_table => import_content_templates(template_list: template_list, content_object: content_object, validation: validation) })
        end
        errors
      end

      def self.import_content_templates(template_list:, content_object:, validation: true)
        errors = {}
        template_list.each do |template_location|
          template = YAML.load(File.open(template_location[:file]))[template_location[:position]]
          error = {}
          error = validate(template) if validation
          if error.blank?
            # puts "write data_set (#{content_object.class_name}): #{template[:data][:name]}"
            data_set = content_object
              .find_or_initialize_by(
                template_name: template[:data][:name],
                template: true
              )
            data_set.seen_at = Time.zone.now
            data_set.schema = template[:data]
            data_set.save
          else
            errors[template[:data][:name]] = error unless error.blank?
          end
        end
        errors
      rescue StandardError => e
        puts "could not access a YML File #{template_location[:file]}"
        puts e.message
        puts e.backtrace
      end

      def self.validate(template)
        result_header = validate_header.call(template)
        errors = {}
        error = result_header.errors
        errors[:head] = error unless error.blank?
        error = validate_properties(template[:data])
        errors[:properties] = error unless error.blank?
        errors
      end

      def self.validate_properties(template)
        errors = {}
        template[:properties].each do |property_name, property_definition|
          result_property = validate_property.call(property_definition)
          error = result_property.errors(full: true)
          error.merge!(validate_properties(property_definition)) if property_definition.key?(:properties)
          # ap property_definition if !result_property.success?
          errors[property_name] = error unless error.blank?
        end
        errors
      end

      def self.validate_header
        Dry::Validation.Schema do
          required(:data).schema do
            required(:name) { str? }
            required(:type) { str? & eql?('object') }
            optional(:content_type) { str? & included_in?(['variant', 'embedded', 'entity', 'container']) }
            optional(:releasable) { bool? }
            optional(:permissions).schema do
              required(:read_write) { bool? }
            end
            optional(:boost) { float? }
            required(:properties)
          end
        end
      end

      def self.validate_property
        Dry::Validation.Schema do
          configure do
            def valid_classification?(value)
              # TODO: check if required ? (external categories can not be found before import)
              # ! DataCycleCore::ClassificationAlias.find_by(name: value).nil?
              true
            end

            def instantiable?(value)
              clazz = ('DataCycleCore::' + value.classify).safe_constantize
              !clazz.nil? && clazz.new.is_a?(ActiveRecord::Base)
            end

            def self.messages
              super.merge(
                en: {
                  errors: {
                    key_attribute: 'keys are UUIDs in DataCycleCore, therefore :type and :storage_type must be defined as strings',
                    embeddedLinkArray: 'type_name must be a table_name (plural), storage_type = array, storage_location = jsonb field(metadata, content)',
                    embeddedLink: 'type_name must be a table_name (plural), storage_location = jsonb field(metadata, content)',
                    classification_relation: "type must be 'classificationTreeLabel' and type_name must be a name of a ClassificationTreeLabel record: #{DataCycleCore::ClassificationTreeLabel.pluck(:name)}",
                    embedded_object: 'type must be object, storage_location must be a content_table_name',
                    included_object: 'storage_location must be a jsonb field, type must be object and must have properties',
                    valid_classification?: 'specified default_value could not be found in classification_aliases',
                    instantiable?: 'must be a string_name (plural) of a database table and the corresponding model must be a child of ActiveRecord::Base.',
                    asset_relation: "type must be 'asset' and type_name must be a name of a AssetType"
                  }
                }
              )
            end
          end

          required(:label) { str? }
          required(:type) do
            str? &
              included_in?(
                [
                  'string',
                  'text',
                  'number',
                  'geographic',
                  'object',
                  'embeddedLinkArray',
                  'embeddedLink',
                  'classificationTreeLabel',
                  'asset'
                ]
              )
          end
          required(:storage_location) do
            str? &
              included_in?(
                [
                  'key',
                  'column',
                  'metadata',
                  'content',
                  'properties',
                  'classification_relation',
                  'asset_relation'
                ] + DataCycleCore.content_tables
              )
          end
          # TODO: add type_name validation after polymorphic relation tables
          # optional(:type_name) {
          #   str? &
          #   included_in?(
          #     DataCycleCore.content_tables+['users','Rechte']+
          #     DataCycleCore::ClassificationTreeLabel.pluck(:name)
          #   )
          # }
          optional(:storage_type) do
            str? &
              included_in?(
                [
                  'string',
                  'text',
                  'number',
                  'geographic',
                  'array'
                ]
              )
          end
          optional(:name) { str? }
          optional(:delete) { bool? }
          optional(:search) { bool? }
          optional(:editor) { hash? }
          optional(:validations) { hash? }
          optional(:properties) { hash? }
          optional(:default_value) { str? & valid_classification? }

          rule(key_attribute: [:storage_location, :type, :storage_type]) do |storage_location, type, storage_type|
            storage_location.eql?('key') > (storage_type.eql?('string') & type.eql?('string'))
          end

          rule(embeddedLinkArray: [:type, :type_name, :storage_type, :storage_location]) do |type, type_name, storage_type, storage_location|
            type.eql?('embeddedLinkArray') > (
            type_name.instantiable? &
              storage_type.eql?('array') &
              storage_location.included_in?(['metadata', 'content', 'properties'])
            )
          end

          rule(embeddedLink: [:type, :type_name, :storage_type, :storage_location]) do |type, type_name, _storage_type, storage_location|
            type.eql?('embeddedLink') > (
            type_name.instantiable? &
              storage_location.included_in?(['metadata', 'content', 'properties'])
            )
          end

          rule(classification_relation: [:storage_location, :type, :type_name, :default_value]) do |storage_location, type, type_name, _default_value|
            (storage_location.eql?('classification_relation') > (
            type.eql?('classificationTreeLabel') &
              type_name.included_in?(DataCycleCore::ClassificationTreeLabel.pluck(:name) + ['Rechte'])
            )) & (type.eql?('classificationTreeLabel') > (
            storage_location.eql?('classification_relation') &
              type_name.included_in?(DataCycleCore::ClassificationTreeLabel.pluck(:name) + ['Rechte'])
            ))
          end

          rule(embedded_object: [:storage_location, :type, :name]) do |storage_location, type, name|
            (storage_location.included_in?(DataCycleCore.content_tables) > (
            type.eql?('object') & name.filled?)
            ) & (
              (type.eql?('object') & name.filled?) >
              storage_location.included_in?(DataCycleCore.content_tables)
            )
          end

          rule(included_object: [:storage_location, :type, :properties]) do |storage_location, type, properties|
            properties.filled? > (
            type.eql?('object') &
              storage_location.included_in?(['metadata', 'content', 'properties'])
            )
          end
        end
      end
    end
  end
end
