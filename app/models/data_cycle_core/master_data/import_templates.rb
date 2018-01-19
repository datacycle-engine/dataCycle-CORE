module DataCycleCore
  module MasterData
    class ImportTemplates
      def import(files, object, validation = true)
        errors = {}
        file_names = Dir[files]
        file_names.each do |filename|
          data_templates = YAML.load(File.open(filename.to_s))
          error = iterate_templates(data_templates, object, validation)
          errors[filename] = error unless error.blank?
        end
        errors
      rescue StandardError => e
        puts "could not access a YML File in directory #{files}"
        puts e.message
        puts e.backtrace
      end

      def iterate_templates(data_templates, object, validation)
        errors = {}
        data_templates.each do |template|
          error = {}
          error = validate(template) if validation
          if error.blank?
            data_set = object
              .find_or_initialize_by(
                headline: template[:data][:name],
                description: template[:data][:description],
                template: true
              )
            data_set.seen_at = Time.zone.now
            if data_set.metadata.blank?
              data_set.metadata = { validation: template[:data] }
            else
              data_set.metadata[:validation] = template[:data]
            end
            data_set.save
          else
            errors[template[:data][:name]] = error unless error.blank?
          end
        end
        errors
      end

      def validate(template)
        result_header = validate_header.call(template)
        errors = {}
        error = result_header.errors
        errors[:head] = error unless error.blank?
        error = validate_properties(template[:data])
        errors[:properties] = error unless error.blank?
        errors
      end

      def validate_properties(template)
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

      def validate_header
        Dry::Validation.Schema do
          required(:data).schema do
            required(:name) { str? }
            required(:description) { str? & included_in?(DataCycleCore.content_tables.map(&:classify) + ['ImageObject', 'VideoObject']) }
            required(:type) { str? & eql?('object') }
            optional(:content_type) { str? & included_in?(['variant', 'embedded', 'entity']) }
            optional(:releasable) { bool? }
            optional(:permissions).schema do
              required(:read_write) { bool? }
            end
            optional(:boost) { float? }
            required(:properties)
          end
        end
      end

      def validate_property
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
                    embedded_object: 'type must be object, description must be a content_table class_name',
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
              included_in?([
                             'string',
                             'text',
                             'number',
                             'geographic',
                             'object',
                             'embeddedLinkArray',
                             'embeddedLink',
                             'classificationTreeLabel',
                             'asset'
                           ])
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
              included_in?([
                             'string',
                             'text',
                             'number',
                             'geographic',
                             'array'
                           ])
          end
          optional(:name) { str? }
          optional(:description) { str? }
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

          rule(embeddedLink: [:type, :type_name, :storage_type, :storage_location]) do |type, type_name, storage_type, storage_location|
            type.eql?('embeddedLink') > (
            type_name.instantiable? &
              storage_location.included_in?(['metadata', 'content', 'properties'])
            )
          end

          rule(classification_relation: [:storage_location, :type, :type_name, :default_value]) do |storage_location, type, type_name, default_value|
            (storage_location.eql?('classification_relation') > (
            type.eql?('classificationTreeLabel') &
              type_name.included_in?(DataCycleCore::ClassificationTreeLabel.pluck(:name) + ['Rechte'])
            )) & (type.eql?('classificationTreeLabel') > (
            storage_location.eql?('classification_relation') &
              type_name.included_in?(DataCycleCore::ClassificationTreeLabel.pluck(:name) + ['Rechte'])
            ))
          end

          rule(embedded_object: [:storage_location, :type, :name, :description]) do |storage_location, type, name, description|
            (storage_location.included_in?(DataCycleCore.content_tables) > (
            type.eql?('object') &
              description.included_in?(DataCycleCore.content_tables.map(&:classify)) &
              name.filled?
            )) & (
              (type.eql?('object') & name.filled? & description.filled?) >
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
