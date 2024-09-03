# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Templates
      class TemplateImporter
        CONTENT_SETS = [:creative_works, :events, :media_objects, :organizations, :persons, :places, :products, :things, :intangibles].freeze

        attr_reader :duplicates, :mixin_errors, :errors, :mixin_paths, :templates

        def initialize(validation: true, template_paths: nil)
          @validation = validation
          @template_paths = template_paths.presence || [DataCycleCore.default_template_paths, DataCycleCore.template_path].flatten.uniq.compact
          @duplicates = {}
          @errors = []
          @mixin_paths = []

          mixins_importer = MixinsImporter.new(template_paths: @template_paths)
          mixins_importer.import
          @mixins = mixins_importer.mixins
          @mixin_errors = mixins_importer.errors

          return if @mixin_errors.present?

          @template_definitions = []
          @extended_templates = []
          @templates = {}

          load_templates

          @validator = TemplateValidator.new(templates: @templates)
        end

        def import
          return unless valid?

          @validator.validate

          return @errors.concat(@validator.errors) unless @validator.valid?

          ActiveRecord::Base.transaction(joinable: false, requires_new: true) do
            begin
              update_templates
              update_schema_types
            rescue StandardError => e
              @errors.push("import error => #{e}")
            end

            raise ActiveRecord::Rollback if @errors.present?
          end
        end

        def validate
          return unless valid?

          @validator.validate

          @errors.concat(@validator.errors)
        end

        def valid?
          @errors.blank? && @mixin_errors.blank?
        end

        # rubocop:disable Rails/Output
        def render_duplicates
          return if @duplicates.blank?

          puts 'INFO: the following templates are overwritten:'
          ap @duplicates
        end

        def render_mixin_errors
          return if @mixin_errors.blank?

          puts 'the following mixins have multiple definitions or file_name does not match mixin name:'
          ap @mixin_errors
        end

        def render_errors
          return if @errors.blank?

          puts 'the following errors were encountered during import:'
          ap @errors
        end

        def render_mixin_paths
          return if @mixin_paths.blank?

          puts 'the following mixins were used for properties:'
          ap @mixin_paths.sort
        end
        # rubocop:enable Rails/Output

        private

        def update_templates
          DataCycleCore::ThingTemplate.upsert_all(@templates.values.flatten.map do |t|
            {
              template_name: t[:name],
              schema: t[:data],
              updated_at: Time.zone.now
            }
          end, unique_by: :template_name)
        end

        def update_schema_types
          schema_types = []
          tree_label = DataCycleCore::ClassificationTreeLabel.create_with(internal: true).find_or_create_by!(name: 'SchemaTypes')

          DataCycleCore::ThingTemplate.where.not(content_type: 'embedded').find_each do |thing_template|
            thing_template.schema_types.each do |types|
              next if schema_types.any? { |st| st[:full_path_names] == types }

              schema_types.push({
                path: types
              })
            end
          end

          tree_label.insert_all_classifications_by_path(schema_types)
        end

        def load_templates
          @template_paths.each do |path|
            CONTENT_SETS.each do |set|
              load_templates_from_path(path, set)
            end
          end

          transform_template_definitions!

          @templates
        end

        def load_templates_from_path(template_path, set)
          Dir[File.join(template_path, set.to_s, '*.yml')].each do |path|
            data_templates = Array.wrap(YAML.safe_load(File.open(path.to_s), permitted_classes: [Symbol], aliases: true))

            data_templates.each do |template|
              @template_definitions.push({
                path:,
                data: template[:data],
                set:
              })
            end
          rescue StandardError => e
            @errors.push("error loading YML File (#{path}) => #{e.message}")
          end
        end

        def append_error!(error, data_template, template)
          if error.is_a?(TemplateError)
            @errors.push("#{[data_template[:set], template[:name], error.path].compact.join('.')} => #{error.message}")
          else
            @errors.push("#{data_template[:set]}.#{template[:name]} => #{error.message}")
          end
        end

        def extend_templates!
          while @template_definitions.present?
            begin
              data_template = @template_definitions.shift
              template = data_template[:data]

              next @template_definitions.push(data_template) unless template_dependencies_ready?(template)

              data = extend_template_data(template:, data_template:)
              next if data.nil?

              append_extended_template!(data:)
            rescue StandardError => e
              append_error!(e, data_template, template)
            end
          end
        end

        def transform_template_definitions!
          extend_templates!

          @extended_templates.each do |data_template|
            template = data_template[:data]
            data = transform_template_data(template:, data_template:)
            next if data.nil?

            add_aggregate_template!(data:, data_template:)
            append_template!(data:)
          rescue StandardError => e
            append_error!(e, data_template, template)
          end

          add_inverse_aggregate_property!
        end

        def append_template!(data:)
          @templates[data[:set]] ||= []
          @templates[data[:set]].push(data)
          @mixin_paths.concat(data[:mixins])
        end

        def add_aggregate_template!(data:, data_template:)
          return unless DataCycleCore.features.dig(:aggregate, :enabled)
          return unless data.dig(:data, :features, :aggregate, :allowed)

          aggregate_template = AggregateTemplate.new(data: data[:data])
          aggregate_data = transform_template_data(template: aggregate_template.import, data_template:)
          return if aggregate_data.nil?

          append_template!(data: aggregate_data)
        end

        def add_inverse_aggregate_property!
          all_templates = @templates.values.flatten
          all_templates.each do |template|
            next unless template.dig(:data, :features, :aggregate, :aggregate)

            aggregated_templates = Array.wrap(
              template.dig(:data, :properties, AggregateTemplate::AGGREGATE_PROPERTY_NAME, :template_name)
            )

            aggregated_templates.each do |template_name|
              aggregated_template = all_templates.find { |v| v[:name] == template_name }

              raise TemplateError.new('features.aggregate.additional_base_templates'), "BaseTemplate missing for #{template_name}" if aggregated_template.nil?

              AggregateTemplate.merge_belongs_to_aggregate_property!(
                data: aggregated_template[:data],
                aggregate_name: template[:name]
              )
            rescue StandardError => e
              append_error!(e, template, template[:data])
            end
          end
        end

        def extend_template_data(template:, data_template:)
          transformed_data = TemplateTransformer.merge_base_templates(template:, templates: @extended_templates)

          {
            name: transformed_data[:name],
            path: data_template[:path],
            data: transformed_data,
            set: data_template[:set]
          }
        end

        def transform_template_data(template:, data_template:)
          transformer = TemplateTransformer.new(template:, content_set: data_template[:set], mixins: @mixins, templates: @templates)
          transformed_data, errors = transformer.transform
          @errors.concat(errors) && return if errors.present?

          {
            name: transformed_data[:name],
            path: data_template[:path],
            data: transformed_data,
            set: data_template[:set],
            mixins: transformer.mixin_paths
          }
        end

        def template_complete?(template, template_definitions)
          name = template[:name].nil? ? template[:extends] : template[:name]

          template_definitions.none? do |v|
            v.dig(:data, :name).nil? ? v.dig(:data, :extends) == name : v.dig(:data, :name) == name
          end
        end

        def append_extended_template!(data:)
          if (duplicate = @extended_templates.find { |v| v[:name] == data[:name] }).present?
            merge_duplicate_template!(data:, duplicate:)
          else
            @extended_templates.push(data)
          end
        end

        def base_templates_exist?(template_names)
          template_names.each do |t_name|
            next if @extended_templates.any? { |v| v[:name] == t_name }

            raise TemplateError.new('extends'), "BaseTemplate missing for #{t_name}" unless base_template?(t_name)

            return false
          end

          true
        end

        def base_template?(base_name)
          @template_definitions.any? do |v|
            v.dig(:data, :name) == base_name &&
              (
                v.dig(:data, :extends).blank? ||
                Array.wrap(v.dig(:data, :extends)).exclude?(v.dig(:data, :name))
              )
          end
        end

        def overrides_in_queue?(template_name)
          @template_definitions.any? do |v|
            e_names = Array.wrap(v.dig(:data, :extends))

            e_names.include?(template_name) &&
              (v.dig(:data, :name).blank? || e_names.include?(v.dig(:data, :name)))
          end
        end

        def template_dependencies_ready?(template)
          return true unless template.key?(:extends)

          extends_templates = Array.wrap(template[:extends])

          # check if all BaseTemplates for extends templates exist
          return false unless base_templates_exist?(extends_templates)

          # remove extends_templates, if template overrides one of its extends templates
          extends_templates.pop if template[:name].blank?
          extends_templates.delete(template[:name]) if extends_templates.include?(template[:name])

          return true if extends_templates.blank?

          # check if any of the extends templates have overrides in queue
          extends_templates.none? { overrides_in_queue?(_1) }
        end

        def merge_duplicate_template!(data:, duplicate:)
          key = "#{data[:set]}.#{data[:name]}"
          @duplicates[key] ||= []
          @duplicates[key].push(duplicate[:path])
          @duplicates[key].push(data[:path])
          @duplicates[key].uniq!

          duplicate.merge!(data)
        end
      end
    end
  end
end
