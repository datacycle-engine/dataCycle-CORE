# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Templates
      class MixinsImporter
        attr_reader :mixins, :errors

        def initialize(template_paths: nil)
          @template_paths = template_paths.presence || [DataCycleCore.default_template_paths, DataCycleCore.template_path].flatten.uniq.compact
          @mixins = {}
          @errors = []
          @mixins_folder = 'mixins'
          @content_sets = TemplateImporter::CONTENT_SETS + [nil]
        end

        def import
          @template_paths.reverse_each do |core_template_path|
            @content_sets.each do |content_set_name|
              Dir[File.join(core_template_path, content_set_name.to_s, @mixins_folder, '*.yml')].each do |path|
                data_templates = YAML.safe_load(File.open(path.to_s), permitted_classes: [Symbol])

                next @errors.push(path) if data_templates.many?

                name = data_templates.dig(0, :data, :name).to_sym
                next @errors.push(path) if File.basename(path).exclude?(name.to_s)

                name_prefix = File.basename(path).delete_suffix("#{name}.yml").delete_suffix('_')

                data = {
                  path:,
                  relative_path: path.delete_prefix(core_template_path.to_s),
                  set: content_set_name,
                  specificity: 0,
                  properties: data_templates.dig(0, :data, :properties)
                }

                if name_prefix.present? && TemplateImporter::CONTENT_SETS.exclude?(name_prefix)
                  data[:template_name] = name_prefix
                  data[:specificity] = 2
                elsif name_prefix.present? || data[:set].present?
                  data[:set] ||= name_prefix.to_sym
                  data[:specificity] = 1
                end

                unless @mixins[name]&.any? { |v| v[:relative_path] == data[:relative_path] && v[:set] == data[:set] }
                  @mixins[name] ||= []
                  @mixins[name].push(data)
                end
              end
            end
          end

          @mixins.each_value { |v| v.sort_by! { |h| [-h[:specificity], -h[:relative_path].count(File::SEPARATOR)] } }
        end
      end
    end
  end
end
