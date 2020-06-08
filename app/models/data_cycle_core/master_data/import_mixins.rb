# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module ImportMixins
      def self.import_all(validation: true, template_paths: nil)
        template_paths ||= [DataCycleCore.default_template_paths, DataCycleCore.template_path].flatten.uniq.compact
        mixin_list, duplicates = import_all_mixins(template_paths: template_paths, _validation: validation)
        return mixin_list, duplicates
      end

      # TODO: add validations + errors + warnings
      def self.import_all_mixins(template_paths:, content_sets:, _validation: true)
        mixins_folder = 'mixins'
        collisions = {}
        mixin_list = {}

        (content_sets + ['default']).each do |content_set_name|
          mixin_list[content_set_name.to_sym] = {}
          collisions[content_set_name.to_sym] = {}
        end

        template_paths.each do |core_template_path|
          (content_sets + ['default']).each do |content_set_name|
            if content_set_name == 'default'
              files = core_template_path + mixins_folder + '*.yml'
            else
              files = core_template_path + content_set_name + mixins_folder + '*.yml'
            end

            file_names = Dir[files]
            file_names.each do |file_name|
              data_templates = YAML.load(File.open(file_name.to_s))
              data_templates.each_index do |index|
                new_template_data = { name: data_templates[index][:data][:name], properties: data_templates[index][:data][:properties], file: file_name, position: index }
                if mixin_list[content_set_name.to_sym].key?(new_template_data[:name].to_sym).present?
                  collisions[content_set_name.to_sym][new_template_data[:name].to_sym] ||= [mixin_list[content_set_name.to_sym][new_template_data[:name].to_sym].except(:name, :properties)]
                  collisions[content_set_name.to_sym][new_template_data[:name].to_sym] += [new_template_data.except(:properties, :name)]
                end
                mixin_list[content_set_name.to_sym][new_template_data[:name].to_sym] = new_template_data
              end
            end
          end
        end

        return mixin_list, collisions.reject { |_, value| value.blank? }.map { |key, value| { key => value.dup } }.inject(&:merge)
      end
    end
  end
end
