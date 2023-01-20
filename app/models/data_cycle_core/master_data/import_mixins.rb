# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module ImportMixins
      def self.import_all(validation: true, template_paths: nil)
        template_paths ||= [DataCycleCore.default_template_paths, DataCycleCore.template_path].flatten.uniq.compact
        mixin_list, mixin_errors = import_all_mixins(template_paths: template_paths, _validation: validation)
        return mixin_list, mixin_errors
      end

      # TODO: add validations + errors + warnings
      def self.import_all_mixins(template_paths:, content_sets:, _validation: true)
        mixins_folder = 'mixins'
        mixin_list = {}
        mixin_errors = []
        set_list = content_sets + [nil]

        template_paths.reverse_each do |core_template_path|
          set_list.each do |content_set_name|
            set_mixins = {}

            Dir[core_template_path + content_set_name.to_s + mixins_folder + '*.yml'].each do |file_path|
              data_templates = YAML.safe_load(File.open(file_path.to_s), [Symbol])

              next mixin_errors.push(file_path) if data_templates.many?

              name = data_templates.dig(0, :data, :name).to_sym
              set_mixins[name] = [] unless set_mixins.key?(name)
              name_prefix = File.basename(file_path).delete_suffix("#{name}.yml").delete_suffix('_')

              data = {
                path: file_path,
                relative_path: file_path.delete_prefix(core_template_path.to_s),
                set: content_set_name,
                specificity: 0,
                properties: data_templates.dig(0, :data, :properties)
              }

              if name_prefix&.in?(content_sets)
                data[:set] ||= name_prefix
                data[:specificity] = 1
              elsif name_prefix.present?
                data[:template_name] = name_prefix
                data[:specificity] = 2
              end

              set_mixins[name].push(data)
            end

            set_mixins.each_value { |v| v.sort_by! { |h| -h[:specificity] } }
            mixin_list.deep_merge!(set_mixins) { |_, v1, v2| v1.is_a?(::Array) && v2.is_a?(::Array) ? v1.concat(v2) : v2 }
          end
        end

        mixin_list.each_value { |v| v.uniq! { |m| m.values_at(:relative_path, :set) } }

        return mixin_list, mixin_errors
      end
    end
  end
end
