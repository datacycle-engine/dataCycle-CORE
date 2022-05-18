# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module ImportTemplates
      CONTENT_SETS = ['creative_works', 'events', 'media_objects', 'organizations', 'persons', 'places', 'products', 'things', 'intangibles'].freeze

      def self.import_all(validation: true, template_paths: nil)
        template_paths ||= [DataCycleCore.default_template_paths, DataCycleCore.template_path].flatten.uniq.compact
        import_hash, duplicates = check_for_duplicates(template_paths, CONTENT_SETS)
        mixin_list, mixin_duplicates = DataCycleCore::MasterData::ImportMixins.import_all_mixins(template_paths: template_paths, content_sets: CONTENT_SETS)
        errors = import_all_templates(template_hash: import_hash, validation: validation, mixins: mixin_list)
        format_errors = errors.reject { |_, value| value.blank? }.map { |key, value| { key => value.deep_dup } }.inject(&:merge) || {}
        # TODO: add notice + warning
        return format_errors, reformat_duplicates(duplicates), reformat_duplicates(mixin_duplicates)
      end

      def self.reformat_duplicates(hash)
        hash&.map { |directory, templates| { directory => templates.map { |template, file_list| { template => file_list.map { |item| item.dig(:file) } } } } } || {}
      end

      def self.import_template_list(template_paths: nil)
        template_paths ||= [DataCycleCore.default_template_paths, DataCycleCore.template_path].flatten.uniq.compact
        import_hash, _duplicates = check_for_duplicates(template_paths, CONTENT_SETS)
        import_hash.map { |_key, value| value }.reduce([], :+).map { |item| item[:name] }.uniq.sort
      end

      def self.check_for_duplicates(template_paths, content_sets)
        import_list = {}
        collisions = {}
        content_sets.each do |content_set_name|
          import_list[content_set_name.to_sym] = []
          collisions[content_set_name.to_sym] = {}
        end

        template_paths.each do |core_template_path|
          content_sets.each do |content_set_name|
            files = core_template_path + content_set_name + '*.yml'
            file_names = Dir[files].sort
            file_names.each do |file_name|
              data_templates = YAML.safe_load(File.open(file_name.to_s), [Symbol])
              data_templates.each_index do |index|
                already_exist_index = import_list[content_set_name.to_sym].index { |item| item[:name] == data_templates[index][:data][:name] }
                new_template_data = { name: data_templates[index][:data][:name], file: file_name, position: index }
                if already_exist_index.nil?
                  import_list[content_set_name.to_sym] += [new_template_data]
                else
                  collisions[content_set_name.to_sym] = collisions[content_set_name.to_sym].merge({ new_template_data[:name] => [import_list[content_set_name.to_sym][already_exist_index].except(:name, :position)] }) if collisions[content_set_name.to_sym][new_template_data[:name]].blank?
                  collisions[content_set_name.to_sym][new_template_data[:name]] += [{ file: file_name }]
                  import_list[content_set_name.to_sym][already_exist_index] = new_template_data
                end
              end
            end
          end
        end
        return import_list, collisions.reject { |_, value| value.blank? }.map { |key, value| { key => value.dup } }.inject(&:merge)
      end

      def self.import_all_templates(template_hash:, validation: true, mixins:)
        errors = {}
        template_hash.each do |content_set, template_list|
          errors = errors.merge({ content_set => import_content_templates(template_list: template_list, content_set: content_set, validation: validation, mixins: mixins) })
        end
        errors
      end

      def self.import_content_templates(template_list:, content_set:, validation: true, mixins:)
        errors = {}
        template_list.each do |template_location|
          template = YAML.safe_load(File.open(template_location[:file]), [Symbol])[template_location[:position]]
          template[:data] = transform_schema(schema: template[:data].dup, content_set: content_set, mixins: mixins)
          error = {}
          error = validate(template) if validation
          if error.blank?
            # puts "write data_set (#{content_set}): #{template[:data][:name]}"
            data_set = DataCycleCore::Thing
              .find_or_initialize_by(
                template_name: template[:data][:name],
                template: true
              )
            data_set.template_updated_at = Time.zone.now
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

      def self.transform_schema(content_set: nil, schema: {}, mixins:)
        schema[:boost] = schema[:boost] || 1.0
        schema[:features] = transform_features(schema: schema, content_set: content_set)
        schema[:properties] = transform_properties(schema: schema, content_set: content_set, mixins: mixins)
        schema[:api] = transform_api_properties(schema: schema, content_set: content_set)
        schema
      end

      def self.transform_features(schema: {}, content_set: nil)
        return schema[:features].deep_merge(DataCycleCore.main_config.dig(:templates, content_set.to_sym, schema.dig(:name).to_sym, :features)&.deep_symbolize_keys) if DataCycleCore.main_config.dig(:templates, content_set.to_sym, schema.dig(:name).to_sym, :features).present?
        schema.dig(:features) || {}
      end

      def self.transform_api_properties(schema: {}, content_set: nil)
        return DataCycleCore.main_config.dig(:templates, content_set.to_sym, schema.dig(:name).to_sym, :api)&.deep_symbolize_keys if DataCycleCore.main_config.dig(:templates, content_set.to_sym, schema.dig(:name).to_sym, :api).present?
        schema.dig(:api) || {}
      end

      def self.transform_properties(schema: {}, content_set: nil, mixins: nil)
        new_properties = {}.with_indifferent_access
        sorting = 1

        schema[:properties].each do |property_name, property_value|
          # TODO: refactor: add errors + warnings
          if property_value[:type] == 'mixin'
            mixin_properties, sorting = add_mixin_properties(content_set, property_value[:name].to_sym, sorting, mixins)
            new_properties.merge!(mixin_properties)
          else
            new_properties[property_name.to_sym], sorting = add_sorting(property_value, sorting)
          end
        end

        new_properties.deep_merge(DataCycleCore.main_config.dig(:templates, content_set, schema.dig(:name), :properties) || {})
      end

      # add mixins recursively
      def self.add_mixin_properties(content_set, property_name, sorting, mixins)
        mixin_properties = {}
        if !content_set.nil? && mixins.dig(content_set.to_sym, property_name).present?
          mixin_set = content_set.to_sym
        elsif mixins.dig(:default, property_name).present?
          mixin_set = :default
        else
          raise "mixin for #{property_name} not found".inspect
        end

        return {}, sorting if mixins.dig(mixin_set, property_name, :properties).blank?

        mixins.dig(mixin_set, property_name, :properties).each do |key, prop|
          if prop[:type] == 'mixin'
            further_mixin_properties, sorting = add_mixin_properties(content_set, prop[:name].to_sym, sorting, mixins)
            mixin_properties.merge!(further_mixin_properties)
          else
            mixin_properties[key.to_sym], sorting = add_sorting(prop, sorting)
          end
        end

        return mixin_properties, sorting
      end

      def self.add_sorting(hash, sorting)
        hash[:properties] = transform_properties(schema: hash) if hash[:type] == 'object' && hash.key?(:properties).present?
        hash[:sorting] = sorting
        return hash, sorting + 1
      end

      def self.validate(template)
        validate_header = TemplateHeaderContract.new
        result_header = validate_header.call(template)
        errors = {}
        error = result_header.errors.to_h
        errors[:head] = error if error.present?

        error = validate_properties(template[:data])
        errors[:properties] = error if error.present?

        error = validate_property_names(template.dig(:data, :properties))
        errors[:property_names] = error if error.present?

        errors
      end

      def self.validate_property_names(properties)
        simple_objects = properties.select { |_, v| v['type'] == 'object' }
        return if simple_objects.blank?
        sub_keys = simple_objects.map { |_, v| v['properties'].keys }.flatten
        root_keys = properties.keys
        return if (root_keys & sub_keys).blank?
        "Simple Objects Error: keys #{root_keys & sub_keys} are not unique!"
      end

      def self.validate_properties(template)
        validate_property = TemplatePropertyContract.new
        errors = {}
        template[:properties].each do |property_name, property_definition|
          result_property = validate_property.call(property_definition)
          error = result_property.errors.to_h
          error.merge!(validate_properties(property_definition)) if property_definition.key?(:properties)
          errors[property_name] = error if error.present?
        end
        errors
      end

      class TemplateHeaderContract < DataCycleCore::MasterData::Contracts::GeneralContract
        schema do
          required(:data).hash do
            required(:name) { str? }
            required(:type) { str? & eql?('object') }
            required(:schema_type) { str? }
            required(:content_type) { str? & included_in?(['embedded', 'entity', 'container']) }
            optional(:boost) { float? }
            optional(:features) { hash? }
            required(:properties).hash do
              required(:id) { hash? }
            end
            optional(:api).hash do
              optional(:type) { str? | array? }
            end
          end
        end
      end

      class TemplatePropertyContract < DataCycleCore::MasterData::Contracts::GeneralContract
        schema do
          required(:label) { str? }
          required(:type) do
            str? & included_in?(
              ['key', 'string', 'text', 'number', 'boolean',
               'datetime', 'date', 'geographic', 'slug',
               'object', 'embedded', 'linked', 'classification',
<<<<<<< HEAD
               'asset', 'computed', 'schedule', 'virtual', 'opening_time']
            )
          end
          optional(:storage_location) do
            str? & included_in?(['column', 'value', 'translated_value', 'virtual', 'classification'])
=======
               'asset', 'schedule', 'opening_time',
               'timeseries']
            )
          end
          optional(:storage_location) do
            str? & included_in?(['column', 'value', 'translated_value', 'classification'])
>>>>>>> old/develop
          end
          optional(:template_name) { str? }
          optional(:validations) { hash? }
          optional(:default_value) { str? | hash? } # the default_value is set only on creation of content or translation / can either be a String or a Hash with 'module' and 'method'
          optional(:ui) { hash? }
          optional(:api) { hash? }
          optional(:xml) { hash? }
          optional(:search) { bool? }
          optional(:advanced_search) { bool? }
          optional(:normalize).hash do
            required(:id) do
              str? & included_in?(
                ['sex', 'degree', 'forename', 'surname', 'birthdate',
                 'company', 'email',
                 'street', 'streetnr', 'city', 'zip', 'country',
                 'eventname', 'eventstart', 'eventend',
                 'eventplace', 'longitude', 'latitude']
              )
            end
            required(:type) do
              str? & included_in?(
                ['sex', 'degree', 'forename', 'surname', 'birthdate',
                 'company', 'email',
                 'street', 'streetnr', 'city', 'zip', 'country',
                 'eventname', 'datetime',
                 'eventplace', 'longitude', 'latitude']
              )
            end
          end

          # for type object
          optional(:properties) { hash? }
          # for type embedded and linked
          optional(:stored_filter) { array? }
          # for type embedded
          optional(:translated) { bool? }

          # for type linked
          # valid_linked_language?
          optional(:linked_language) do
            str? & included_in?(
              ['all', 'same']
            )
          end
          optional(:inverse_of) { str? } # for bidirectional links

          # make sure if link_direction = inverse set api: disabled: true
          # validate_link_direction?
          optional(:link_direction) do
            str? & included_in?(
              ['inverse']
            )
          end

          # for type classification
          optional(:tree_label) { str? } # only members of the specified classification_tree are valid values
          optional(:not_translated) { bool? } # true -> classification only exists in german
          optional(:external) { bool? } # true -> only imported can not be manually edited
          optional(:universal) { bool? } # true -> only for universal_classifications... does not need a tree_label
          optional(:global) { bool? } # true -> edit is allowed for imported data

          # for type asset
          optional(:asset_type) do
            str? & included_in?(
              ['asset', 'audio', 'image', 'video', 'pdf', 'data_cycle_file', 'srt_file']
            )
          end

          # for type compute
          optional(:compute).hash do
            required(:module) { str? }
            required(:method) { str? }
            required(:parameters) { hash? }
<<<<<<< HEAD
            required(:type) do
              str? & included_in?(
                ['string', 'text', 'number', 'boolean',
                 'datetime', 'geographic',
                 'object', 'classification', 'asset', 'schedule']
              )
            end
=======
>>>>>>> old/develop
          end
        end

        rule(:type) do
          case value
          when 'object'
            key.failure(:invalid_object) unless values.dig(:properties).present? && ['value', 'translated_value'].include?(values.dig(:storage_location))
          when 'embedded'
            key.failure(:invalid_embedded) unless values.dig(:template_name).present? || values.dig(:stored_filter).present?
          when 'linked'
            key.failure(:invalid_linked) unless values.dig(:template_name).present? || values.dig(:stored_filter).present? || values.dig(:inverse_of).present?
          when 'classification'
            key.failure(:invalid_classification) if values.dig(:tree_label).blank? && values.dig(:universal) == false
          when 'asset'
            key.failure(:invalid_asset) if values.dig(:asset_type).blank?
<<<<<<< HEAD
          when 'computed'
=======
          end
        end

        rule(:compute) do
          if key? && values.present?
>>>>>>> old/develop
            temp = begin
              module_name = ('DataCycleCore::' + values.dig(:compute, :module).classify).safe_constantize
              module_name.respond_to?(values.dig(:compute, :method))
                   rescue StandardError
                     false
            end
            key.failure(:invalid_computed) if temp == false
          end
        end

        rule(:properties) do
          key.failure(:invalid_object) if key? && !(values.dig(:type) == 'object' && ['value', 'translated_value'].include?(values.dig(:storage_location)))
        end
      end

      def self.updated_template_statistics(timestamp = Time.zone.now)
        templates = {}
        DataCycleCore::Thing.where('template_updated_at < ?', timestamp.utc.to_s(:long_usec))
          .where(template: true).find_each do |template|
            templates[template.template_name] = {
              template_updated_at: template.template_updated_at,
              count: DataCycleCore::Thing.where(template: false, template_name: template.template_name).count,
              count_history: DataCycleCore::Thing::History.where(template: false, template_name: template.template_name).count
            }
          end
        templates
          .to_a
          .sort_by { |item| item[1][:template_updated_at] }
          .reduce({}) { |aggregate, item| aggregate.merge({ item[0] => item[1] }) }
      end

      def self.template_statistics
        templates = {}
        history = {}
        DataCycleCore::Thing.where(template: true).pluck(:template_name, :content_type)&.sort&.each do |template, type|
          templates[template] = [type, DataCycleCore::Thing.where(template_name: template, template: false).count]
          history[template] = [type, DataCycleCore::Thing::History.where(template_name: template).count]
        end
        return templates, history
      end

      def self.find_not_translatable_embedded
        not_translatable_list = check_not_translatable
        return [] if not_translatable_list.blank?

        not_translated_occurances = []
        DataCycleCore::Thing.where(template: true).find_each do |template|
          template.embedded_property_names.map { |item|
            { item => template.properties_for(item) }
          }.each do |properties|
            key = properties.keys.first
            next unless properties.dig(key, 'template_name').in?(not_translatable_list)
            next if properties.dig(key, 'translated') == true
            not_translated_occurances.push({ template.template_name => key })
          end
        end
        not_translated_occurances
      end

      def self.check_not_translatable
        templates = []
        DataCycleCore::Thing.where(template: true).find_each do |template|
          properties = template.schema['properties'].with_indifferent_access
          not_trans = DataCycleCore::MasterData::ImportTemplates.not_translatable?(properties)
          templates.push(template.template_name) if not_trans
        end
        templates
      end

      def self.not_translatable?(properties)
        translated_columns = DataCycleCore::Thing.new.translated_attributes
        result = true
        properties.each do |name, property|
          next if property.dig(:type).in? [:key, :classification, :asset, :linked, :embedded]
          return false if property[:storage_location] == 'translated_value'
          return false if property[:storage_location] == 'column' && name.in?(translated_columns)
          result = not_translatable?(property.dig(:properties)) if property.dig(:type) == :object
          return false if result == false
        end
        true
      end
    end
  end
end
