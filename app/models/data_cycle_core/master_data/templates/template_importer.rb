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

          reload_main_config! if Rails.env.development?
          @templates = load_templates
          @validator = TemplateValidator.new(templates: @templates)
        end

        def import
          return unless valid?

          @validator.validate

          return @errors.concat(@validator.errors) unless @validator.valid?

          update_templates
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

        def reload_main_config!
          DataCycleCore.load_configurations_for_file('main_config')
        end

        def update_templates
          DataCycleCore::ThingTemplate.upsert_all(@templates.values.flatten.map do |t|
            {
              template_name: t[:name],
              schema: t[:data],
              updated_at: Time.zone.now
            }
          end, unique_by: :template_name)
        end

        def load_templates
          templates = {}
          template_definitions = []

          @template_paths.each do |core_template_path|
            CONTENT_SETS.each do |content_set_name|
              Dir[File.join(core_template_path, content_set_name.to_s, '*.yml')].each do |path|
                data_templates = Array.wrap(YAML.safe_load(File.open(path.to_s), permitted_classes: [Symbol]))

                data_templates.each do |template|
                  template_definitions.push({
                    path:,
                    data: template[:data],
                    set: content_set_name
                  })
                end
              rescue StandardError => e
                @errors.push("error loading YML File (#{path}) => #{e.message}")
              end
            end
          end

          transform_template_definitions!(template_definitions, templates)

          @mixin_paths = templates.values.flatten.flat_map { |v| v[:mixins] }
          @templates = templates
        end

        def transform_template_definitions!(template_definitions, templates)
          while template_definitions.present?
            data_template = template_definitions.shift
            template = data_template[:data]

            next template_definitions.push(data_template) unless template_dependencies_ready?(template, template_definitions, templates)

            transformer = TemplateTransformer.new(template:, content_set: data_template[:set], mixins: @mixins, templates:)
            transformed_data = transformer.transform

            data = {
              name: transformed_data[:name],
              path: data_template[:path],
              data: transformed_data,
              set: data_template[:set],
              mixins: transformer.mixin_paths
            }

            if (duplicate = templates.values.flatten.find { |v| v[:name] == data[:name] }).present?
              merge_duplicate_template!(data:, duplicate:)
            else
              templates[data_template[:set]] ||= []
              templates[data_template[:set]].push(data)
            end
          end
        end

        def template_dependencies_ready?(template, template_definitions, templates)
          return true unless template.key?(:extends)
          return false if templates.values.flatten.none? { |v| v[:name] == template[:extends] }

          template_definitions.none? do |v|
            v.dig(:data, :extends) == template[:extends] &&
              (v.dig(:data, :name).blank? || v.dig(:data, :name) == v.dig(:data, :extends))
          end
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
