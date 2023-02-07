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
          DataCycleCore::Thing.upsert_all(@templates.values.flatten.map do |t|
            {
              template_name: t[:name],
              template: true,
              cache_valid_since: Time.zone.now,
              schema: t[:data]
            }
          end, unique_by: :things_template_name_template_uq_idx)
        end

        def load_templates
          templates = {}

          @template_paths.each do |core_template_path|
            CONTENT_SETS.each do |content_set_name|
              Dir[File.join(core_template_path, content_set_name.to_s, '*.yml')].sort.each do |path|
                data_templates = YAML.safe_load(File.open(path.to_s), [Symbol])

                data_templates.each do |template|
                  template = template[:data]
                  transformer = TemplateTransformer.new(template: template, content_set: content_set_name, mixins: @mixins)
                  transformed_data = transformer.transform

                  if (duplicate = templates.dig(content_set_name)&.find { |v| v[:name] == template[:name] }).present?
                    key = "#{content_set_name}.#{template[:name]}"
                    @duplicates[key] ||= []
                    @duplicates[key].push(duplicate[:path])
                    @duplicates[key].push(path)
                    @duplicates[key].uniq!

                    duplicate[:path] = path
                    duplicate[:data] = transformed_data

                    @mixin_paths.delete_if { |s| s.start_with?(key) }
                  else
                    templates[content_set_name] ||= []
                    templates[content_set_name].push({
                      name: template[:name],
                      path: path,
                      data: transformed_data
                    })
                  end

                  @mixin_paths.concat(transformer.mixin_paths)
                end
              rescue StandardError => e
                @errors.push("error loading YML File (#{path}) => #{e.message}")
              end
            end
          end

          @templates = templates
        end
      end
    end
  end
end
