module DataCycleCore
  module MasterData
    module ImportTemplates
      def self.import_all(validation: true)
        template_paths = [DataCycleCore.default_template_paths, DataCycleCore.template_path].flatten.uniq.compact
        import_hash, duplicates = check_for_duplicates(template_paths)
        @mixin_list, mixin_duplicates = DataCycleCore::MasterData::ImportMixins.import_all_mixins(template_paths)
        errors = import_all_templates(template_hash: import_hash, validation: validation)
        # TODO: add notice + warning
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
              # new_template_definitions = data_templates.map { |item| item[:data][:name] }
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
          template[:data] = transform_schema(schema: template[:data].dup, content_object: content_object)
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
        puts 'could not access a YML File'
        puts e.message
        puts e.backtrace
      end

      def self.transform_schema(schema: {}, content_object: nil)
        schema[:properties] = transform_properties(property_hash: schema[:properties], content_object: content_object)
        schema
      end

      def self.transform_properties(property_hash: {}, content_object: nil)
        new_properties = {}
        sorting = 1
        property_hash.each do |property_name, property_value|
          # TODO: refactor: add errors + warnings
          if property_value[:type] == 'mixin'
            if !content_object.nil? && @mixin_list.dig(content_object.name.demodulize.pluralize.underscore.to_sym, property_value[:name].to_sym).present?
              active_mixin = @mixin_list[content_object.name.demodulize.pluralize.underscore.to_sym]
            elsif @mixin_list.dig(:default, property_value[:name].to_sym).present?
              active_mixin = @mixin_list[:default]
            else
              raise "mixin for #{property_value[:name]} not found".inspect
            end

            next if active_mixin.dig(property_value[:name].to_sym, :properties).blank?

            active_mixin[property_value[:name].to_sym][:properties].each do |key, prop|
              new_properties[key.to_sym], sorting = add_sorting(prop, sorting)
            end

          else
            new_properties[property_name.to_sym], sorting = add_sorting(property_value, sorting)
          end
        end
        new_properties
      end

      def self.add_sorting(hash, sorting)
        if hash[:type] == 'object' && hash.key?(:properties).present?
          hash[:properties] = transform_properties(property_hash: hash[:properties])
        end
        return hash, sorting + 1
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
            optional(:boost) { float? }
            optional(:features)
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
                    included_object: "type must be 'object' and must have properties defined. storage_location must be a jsonb field (content for translated fields, metadata for not translatable data).",
                    embedded_object: "type must be 'embedded'. either define a stored_filter, or a linked_table (plural) in combination with a template_name",
                    linked_object:   "type must be 'linked'. either define a stored_filter, or a linked_table (plural) in combination with a template_name",
                    asset_relation:  "type must be 'asset' and asset_type must be one of: 'image', 'video', 'file'",
                    classification_relation: "type must be 'classification' and classification_tree one of: #{DataCycleCore::ClassificationTreeLabel.pluck(:name)}",
                    valid_classification?: 'specified default_value could not be found in classification_aliases',
                    instantiable?: 'must be a string_name (plural) of a database table and the corresponding model must be a child of ActiveRecord::Base.'
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
                  'key',
                  'string',
                  'text',
                  'number',
                  'date_time',
                  'geographic',
                  'object',
                  'embedded',
                  'linked',
                  'classification',
                  'asset'
                ]
              )
          end
          optional(:storage_location) do
            str? &
              included_in?(
                [
                  'column',
                  'metadata',
                  'content'
                ]
              )
          end
          optional(:search) { bool? }
          optional(:validations) { hash? }
          optional(:properties) { hash? }
          optional(:UI) { hash? }
          optional(:delete) { bool? }
          optional(:default_value) { str? & valid_classification? }
          optional(:asset_type) do
            str? &
              included_in?(
                [
                  'image',
                  'video',
                  'file'
                ]
              )
          end
          optional(:stored_filter) { str? }

          rule(included_object: [:type, :storage_location, :properties]) do |type, storage_location, properties|
            properties.filled? > (
              type.eql?('object') &
              storage_location.included_in?(['metadata', 'content'])
            )
          end

          rule(embedded_object: [:type, :linked_table, :template_name, :stored_filter]) do |type, linked_table, template_name, stored_filter|
            (type.eql?('embedded') > (linked_table.filled? & template_name.filled?)) |
              (type.eql?('embedded') > stored_filter.filled?)
          end

          rule(linked_object: [:type, :linked_table, :stored_filter]) do |type, linked_table, stored_filter|
            (type.eql?('linked') > linked_table.filled?) |
              (type.eql?('linked') > stored_filter.filled?)
          end

          rule(classification_relation: [:type, :classification_tree]) do |type, classification_tree|
            type.eql?('classification') >
              classification_tree.included_in?(DataCycleCore::ClassificationTreeLabel.pluck(:name) + ['Rechte'])
          end

          rule(asset_relation: [:type, :asset_type]) do |type, asset_type|
            type.eql?('asset') >
              asset_type.filled?
          end
        end
      end
    end
  end
end
