# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module ImportTemplates
      CONTENT_TABLES = ['creative_works', 'events', 'organizations', 'persons', 'places', 'things'].freeze

      def self.import_all(validation: true, template_paths: nil)
        template_paths ||= [DataCycleCore.default_template_paths, DataCycleCore.template_path].flatten.uniq.compact
        import_hash, duplicates = check_for_duplicates(template_paths, CONTENT_TABLES)
        @mixin_list, _mixin_duplicates = DataCycleCore::MasterData::ImportMixins.import_all_mixins(template_paths: template_paths, content_tables: CONTENT_TABLES)
        errors = import_all_templates(template_hash: import_hash, validation: validation)
        # TODO: add notice + warning
        return errors.reject { |_, value| value.blank? }.map { |key, value| { key => value.deep_dup } }.inject(&:merge) || {}, duplicates || {}
      end

      def self.check_for_duplicates(template_paths, content_tables)
        import_list = {}
        collisions = {}
        content_tables.each do |content_table_name|
          import_list[content_table_name.to_sym] = []
          collisions[content_table_name.to_sym] = {}
        end

        template_paths.each do |core_template_path|
          content_tables.each do |content_table_name|
            files = core_template_path + content_table_name + '*.yml'
            file_names = Dir[files]
            file_names.each do |file_name|
              data_templates = YAML.safe_load(File.open(file_name.to_s), [Symbol])
              # new_template_definitions = data_templates.map { |item| item[:data][:name] }
              data_templates.each_index do |index|
                already_exist_index = import_list[content_table_name.to_sym].index { |item| item[:name] == data_templates[index][:data][:name] }
                new_template_data = { name: data_templates[index][:data][:name], file: file_name, position: index }
                if already_exist_index.nil?
                  import_list[content_table_name.to_sym] += [new_template_data]
                else
                  collisions[content_table_name.to_sym] = collisions[content_table_name.to_sym].merge({ new_template_data[:name] => [import_list[content_table_name.to_sym][already_exist_index].except(:name)] }) if collisions[content_table_name.to_sym][new_template_data[:name]].blank?
                  collisions[content_table_name.to_sym][new_template_data[:name]] += [{ file: file_name, position: index }]
                  import_list[content_table_name.to_sym][already_exist_index] = new_template_data
                end
              end
            end
          end
        end
        return import_list, collisions.reject { |_, value| value.blank? }.map { |key, value| { key => value.dup } }.inject(&:merge)
      end

      def self.import_all_templates(template_hash:, validation: true)
        errors = {}
        template_hash.each do |content_table, template_list|
          errors = errors.merge({ content_table => import_content_templates(template_list: template_list, content_table: content_table, validation: validation) })
        end
        errors
      end

      def self.import_content_templates(template_list:, content_table:, validation: true)
        errors = {}
        template_list.each do |template_location|
          template = YAML.safe_load(File.open(template_location[:file]), [Symbol])[template_location[:position]]
          template[:data] = transform_schema(schema: template[:data].dup, content_table: content_table)
          error = {}
          error = validate(template) if validation
          if error.blank?
            # puts "write data_set (#{content_table}): #{template[:data][:name]}"
            data_set = DataCycleCore::Thing
              .find_or_initialize_by(
                template_name: template[:data][:name],
                template: true
              )
            data_set.seen_at = Time.zone.now
            data_set.schema = template[:data]
            data_set.save
          elsif error.present?
            errors[template[:data][:name]] = error
          end
        end
        errors
      rescue StandardError => e
        puts "could not access a YML File: #{template_list}"
        puts e.message
        puts e.backtrace
      end

      def self.transform_schema(content_table: nil, schema: {})
        schema[:properties] = transform_properties(property_hash: schema[:properties], content_table: content_table)
        schema
      end

      def self.transform_properties(property_hash: {}, content_table: nil)
        new_properties = {}
        sorting = 1
        property_hash.each do |property_name, property_value|
          # TODO: refactor: add errors + warnings
          if property_value[:type] == 'mixin'
            if !content_table.nil? && @mixin_list.dig(content_table.to_sym, property_value[:name].to_sym).present?
              active_mixin = @mixin_list[content_table.to_sym]
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
        hash[:properties] = transform_properties(property_hash: hash[:properties]) if hash[:type] == 'object' && hash.key?(:properties).present?
        return apply_sorting(hash, sorting), sorting + 1
      end

      def self.apply_sorting(hash, sorting)
        # ignore sorting, if no editor is set
        # hash[:sorting] = sorting unless hash.dig(:ui, :edit, :disabled).present?
        hash[:sorting] = sorting
        hash
      end

      def self.validate(template)
        result_header = validate_header.call(template)
        errors = {}
        error = result_header.errors
        errors[:head] = error if error.present?
        error = validate_properties(template[:data])
        errors[:properties] = error if error.present?
        errors
      end

      def self.validate_properties(template)
        errors = {}
        template[:properties].each do |property_name, property_definition|
          result_property = validate_property.call(property_definition)
          error = result_property.errors(full: true)
          error.merge!(validate_properties(property_definition)) if property_definition.key?(:properties)
          errors[property_name] = error if error.present?
        end
        errors
      end

      def self.validate_header
        Dry::Validation.Schema do
          required(:data).schema do
            required(:name) { str? }
            required(:type) { str? & eql?('object') }
            required(:schema_type) { str? }
            optional(:content_type) { str? & included_in?(['variant', 'embedded', 'entity', 'container']) }
            optional(:boost) { float? }
            optional(:features) { hash? }
            required(:properties)
          end
        end
      end

      def self.validate_property
        Dry::Validation.Schema do
          configure do
            def valid_classification?(_value)
              # TODO: check if required ? (external categories can not be found before import)
              # ! DataCycleCore::ClassificationAlias.find_by(name: value).nil?
              true
            end

            def valid_compute_config?(value)
              return false unless value.is_a?(Hash)
              module_name = valid_computed_module?(value.dig(:module))
              !module_name.nil? && module_name.respond_to?(value.dig(:method))
            end

            def valid_computed_module?(value)
              ('DataCycleCore::' + value.classify).safe_constantize
            end

            def instantiable?(value)
              clazz = ('DataCycleCore::' + value.classify).safe_constantize
              !clazz.nil? && clazz.new.is_a?(ActiveRecord::Base)
            end

            def self.messages
              super.merge(
                en: {
                  errors: {
                    included_object: "type must be 'object' and must have properties defined. storage_location must be a jsonb field (translated_value for translated fields, value for not translatable data).",
                    embedded_object: "type must be 'embedded'. either define a stored_filter, or a template_name",
                    linked_object: "type must be 'linked'. either define a stored_filter, or a template_name",
                    asset_relation: "type must be 'asset' and asset_type must be one of: 'asset', 'image', 'video', 'data_cycle_file', 'pdf', 'audio'",
                    classification_relation: "type must be 'classification' and classification_tree one of: #{DataCycleCore::ClassificationTreeLabel.pluck(:name) + ['Rechte']}",
                    valid_classification?: 'specified default_value could not be found in classification_aliases',
                    instantiable?: 'must be a string_name (plural) of a database table and the corresponding model must be a child of ActiveRecord::Base.',
                    valid_compute_config?: 'module and method combination not found.'
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
                  'boolean',
                  'datetime',
                  'geographic',
                  'object',
                  'embedded',
                  'linked',
                  'classification',
                  'asset',
                  'computed'
                ]
              )
          end
          optional(:compute).schema do
            required(:module) { str? }
            required(:method) { str? }
            required(:parameters) { hash? }
            required(:type) do
              str? &
                included_in?(
                  [
                    'string',
                    'text',
                    'number',
                    'boolean',
                    'datetime',
                    'geographic',
                    'object',
                    'classification',
                    'asset'
                  ]
                )
            end
          end
          optional(:storage_location) do
            str? &
              included_in?(
                [
                  'column',
                  'value',
                  'translated_value'
                ]
              )
          end
          optional(:search) { bool? }
          optional(:validations) { hash? }
          optional(:properties) { hash? }
          optional(:ui) { hash? }
          optional(:api) { hash? }
          optional(:delete) { bool? }
          optional(:default_value) { str? & valid_classification? }
          optional(:asset_type) do
            str? &
              included_in?(
                [
                  'asset',
                  'audio',
                  'image',
                  'video',
                  'pdf',
                  'data_cycle_file'
                ]
              )
          end
          optional(:tree_label) { str? }
          optional(:stored_filter) { array? }

          rule(included_object: [:type, :storage_location, :properties]) do |type, storage_location, properties|
            properties.filled? > (
              type.eql?('object') &
              storage_location.included_in?(['value', 'translated_value'])
            )
          end

          rule(embedded_object: [:type, :template_name, :stored_filter]) do |type, template_name, stored_filter|
            (type.eql?('embedded') > template_name.filled?) |
              (type.eql?('embedded') > stored_filter.filled?)
          end

          rule(linked_object: [:type, :template_name, :stored_filter]) do |type, template_name, stored_filter|
            (type.eql?('linked') > template_name.filled?) |
              (type.eql?('linked') > stored_filter.filled?)
          end

          rule(classification_relation: [:type, :tree_label]) do |type, tree_label|
            # type.eql?('classification') >
            #   tree_label.included_in?(DataCycleCore::ClassificationTreeLabel.pluck(:name) + ['Rechte'])
            type.eql?('classification') > tree_label.filled?
          end

          rule(asset_relation: [:type, :asset_type]) do |type, asset_type|
            type.eql?('asset') >
              asset_type.filled?
          end

          rule(computed_method: [:type, :compute]) do |type, compute|
            type.eql?('computed') >
              (compute.hash? & compute.valid_compute_config?)
          end
        end
      end
    end
  end
end
