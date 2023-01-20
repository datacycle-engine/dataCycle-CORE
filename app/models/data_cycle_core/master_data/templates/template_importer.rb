# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Templates
      class TemplateImporter
        CONTENT_SETS = [:creative_works, :events, :media_objects, :organizations, :persons, :places, :products, :things, :intangibles].freeze

        attr_reader :duplicates, :mixin_errors, :errors, :mixin_paths

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

          reload_main_config! if Rails.env.development?
          @templates = load_templates
          @validator = TemplateValidator.new(templates: @templates)
        end

        def import
          @validator.validate

          return @errors.concat(@validator.errors) unless @validator.valid?

          update_templates
        end

        def validate
          @validator.validate
          @errors.concat(@validator.errors)
        end

        def valid?
          @errors.blank? && @mixin_errors.blank?
        end

        def reload_main_config!
          DataCycleCore.load_configurations(Rails.root.join('config', 'configurations', Rails.env, 'main_config', '**', '*.yml'))
          DataCycleCore.load_configurations(Rails.root.join('config', 'configurations', Rails.env, 'main_config.yml'))
          DataCycleCore.load_configurations(Rails.root.join('config', 'configurations', 'main_config', '**', '*.yml'), false)
          DataCycleCore.load_configurations(Rails.root.join('config', 'configurations', 'main_config.yml'))
        end

        def update_templates
        end

        def load_templates
          templates = {}

          @template_paths.each do |core_template_path|
            CONTENT_SETS.each do |content_set_name|
              Dir[File.join(core_template_path, content_set_name.to_s, '*.yml')].sort.each do |file_path|
                data_templates = YAML.safe_load(File.open(file_path.to_s), [Symbol])

                data_templates.each do |template|
                  template = template[:data]
                  transformer = TemplateTransformer.new(template: template, content_set: content_set_name, mixins: @mixins)
                  transformed_data = transformer.transform
                  @mixin_paths.concat(transformer.mixin_paths)

                  if (duplicate = templates.dig(content_set_name)&.find { |v| v[:name] == template[:name] }).present?
                    key = "#{content_set_name}.#{template[:name]}"
                    @duplicates[key] ||= []
                    @duplicates[key].push(duplicate[:file_path])
                    @duplicates[key].push(file_path)
                    @duplicates[key].uniq!

                    duplicate[:file_path] = file_path
                    duplicate[:data] = transformed_data
                  else
                    templates[content_set_name] ||= []
                    templates[content_set_name].push({
                      name: template[:name],
                      file_path: file_path,
                      data: transformed_data
                    })
                  end
                end
              rescue StandardError => e
                @errors.push("error loading YML File (#{file_path}) => #{e.message}")
              end
            end
          end

          @templates = templates
        end
      end
    end
  end
end
