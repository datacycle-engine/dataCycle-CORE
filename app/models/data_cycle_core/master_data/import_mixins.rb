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

        return resolve(mixin_list), collisions.reject { |_, value| value.blank? }.map { |key, value| { key => value.dup } }.inject(&:merge)
      end

      # allow for mixins in mixins
      def self.resolve(mixin_list)
        new_mixin_list = {}.with_indifferent_access
        mixin_list.each do |content_set, mixin_sublist|
          new_mixin_list[content_set] = {}
          mixin_sublist.map do |mixin_name, mixin_schema|
            new_mixin_list[content_set][mixin_name] = mixin_schema.except(:properties)
            new_properties = transform_properties(mixin_schema.dig(:properties), content_set, mixin_list)
            new_mixin_list[content_set][mixin_name][:properties] = new_properties || {}
          end
          new_mixin_list[content_set].compact!
        end
        new_mixin_list
      end

      def self.transform_properties(mixin_schema, content_set, mixin_list)
        return if mixin_schema.blank?
        mixin_schema.map do |property_name, property_definitions|
          if property_definitions.dig(:type) == 'mixin'
            transform_properties(get_mixin(property_definitions[:name], content_set, mixin_list), content_set, mixin_list)
          else
            { property_name => property_definitions }
          end
        end&.inject(&:merge!)
      end

      def self.get_mixin(name, set, list)
        if list.dig(set.to_sym, name.to_sym).present?
          mixin_set = set.to_sym
        elsif list.dig(:default, name.to_sym).present?
          mixin_set = :default
        else
          raise "mixin for #{name} not found".inspect
        end
        list.dig(mixin_set, name.to_sym, :properties).presence
      end
    end
  end
end
