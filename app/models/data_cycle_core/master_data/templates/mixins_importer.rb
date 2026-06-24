# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Templates
      class MixinsImporter
        include MixinResolutionPolicy

        attr_reader :mixins, :errors

        def initialize(template_paths: nil)
          @content_sets = TemplateImporter::CONTENT_SETS + [nil]
          @mixins_folder = 'mixins'
          @template_paths = template_paths.presence || [DataCycleCore.default_template_paths, DataCycleCore.template_path].flatten.uniq.compact
          @definitions = []
          @mixins = {}
          @errors = []
        end

        def import
          load_mixin_definitions
          resolve_mixins!
          sort_mixins_in_descending_resolution_order!
        end

        private

        def load_mixin_definitions
          @template_paths.reverse_each.with_index do |core_template_path, template_paths_reverse_index|
            @content_sets.each do |content_set_name|
              Dir[File.join(core_template_path, content_set_name.to_s, @mixins_folder, '*.yml')].each do |path|
                data_templates = YAML.safe_load(File.open(path.to_s), permitted_classes: [Symbol], aliases: true)

                next @errors.push(path) if data_templates.many?

                mixin_data = data_templates.dig(0, :data)
                next @errors.push(path) if mixin_data[:name].blank?

                name = mixin_data[:name].to_sym
                next @errors.push(path) if File.basename(path).exclude?(name.to_s)

                name_prefix = File.basename(path).delete_suffix("#{name}.yml").delete_suffix('_')
                specificity = Specificity.new(name_prefix:, content_set_name:)

                @definitions.push({
                  path:,
                  relative_path: path.delete_prefix(core_template_path.to_s),
                  specificity: specificity.specificity_value,
                  set: specificity.set_name,
                  template_paths_reverse_index: template_paths_reverse_index,
                  template_name: specificity.template_name,
                  properties: mixin_data[:properties],
                  extends: mixin_data[:extends],
                  name:
                })
              end
            end
          end
        end

        def resolve_mixins!
          visited_mixins = Set.new

          while @definitions.present?
            mixin_def = @definitions.shift
            mixin_def_uuid = unique_mixin_identifier(mixin_def)

            unless dependencies_ready?(mixin_def) || visited_mixins.include?(mixin_def_uuid)
              visited_mixins.add(mixin_def_uuid)
              @definitions.push(mixin_def)
              next
            end

            validate_mixin_base_exists!(mixin_def)
            add_mixin_to_collection(mixin_def)
          end
        end

        def unique_mixin_identifier(mixin_def)
          [mixin_def[:name], mixin_def[:set], mixin_def[:template_name]]
        end

        def dependencies_ready?(mixin_def)
          return true if mixin_def[:extends].blank?

          Array.wrap(mixin_def[:extends]).all? do |base_name|
            @mixins[base_name.to_sym]&.any? { |mixin| mixin[:set].nil? || mixin[:set] == mixin_def[:set] }
          end
        end

        def validate_mixin_base_exists!(mixin_def)
          return if mixin_def[:extends].blank?

          Array.wrap(mixin_def[:extends]).each do |base_name|
            next if @mixins[base_name.to_sym]&.any? { |mixin| mixin[:set].nil? || mixin[:set] == mixin_def[:set] }

            template_part = mixin_def[:template_name].present? ? " in template '#{mixin_def[:template_name]}'" : ''
            scope_part = mixin_def[:set].blank? ? '' : " in scope '#{mixin_def[:set]}'"
            @errors.push("Mixin '#{mixin_def[:name]}' extends missing base mixin '#{base_name}'#{template_part}#{scope_part}")
          end
        end

        def add_mixin_to_collection(mixin_def)
          return if @mixins[mixin_def[:name]]&.any? { |mixin| mixin[:path] == mixin_def[:path] }

          resolution_sets = mixin_def[:set].nil? && mixin_def[:extends].present? ? @content_sets : [mixin_def[:set]]

          resolution_sets
            .map { |resolution_set| build_mixin_entry(mixin_def, resolution_set) }
            .each { |mixin_entry| upsert_mixin_entry(mixin_def[:name], mixin_entry, extends: mixin_def[:extends].present?) }
        end

        def build_mixin_entry(mixin_def, set)
          scoped_def = mixin_def.merge(set:)
          resolved_properties = merge_base_mixin_properties(scoped_def).deep_merge(mixin_def[:properties] || {})
          base_name = Array.wrap(mixin_def[:extends]).first
          base_mixin = base_name.present? ? select_best_candidate(@mixins[base_name.to_sym], include_content_set: scoped_def[:set]) : nil

          mixin_entry = scoped_def.except(:name, :extends).merge(properties: resolved_properties)

          if base_mixin.present? && set.present? && base_mixin[:set] == set
            child_file = File.basename(mixin_def[:path])
            mixin_entry[:path] = File.join(File.dirname(base_mixin[:path].to_s), child_file)
            mixin_entry[:relative_path] = File.join(File.dirname(base_mixin[:relative_path].to_s), child_file)
            mixin_entry[:specificity] = base_mixin[:specificity]
          end

          mixin_entry
        end

        def upsert_mixin_entry(name, mixin_entry, extends:)
          @mixins[name] ||= []
          existing_index = @mixins[name].index { |mixin| mixin[:path] == mixin_entry[:path] }

          if existing_index && extends
            @mixins[name][existing_index] = mixin_entry
          elsif existing_index.nil?
            @mixins[name].push(mixin_entry)
          end
        end

        def merge_base_mixin_properties(mixin_def)
          merged_properties = {}

          Array.wrap(mixin_def[:extends]).each do |base_name|
            base_mixin = select_best_candidate(@mixins[base_name.to_sym], include_content_set: mixin_def[:set])
            next if base_mixin.nil?

            merged_properties = merged_properties.deep_merge(base_mixin[:properties] || {})
          end

          merged_properties
        end

        def sort_mixins_in_descending_resolution_order!
          @mixins.each_value { |mixins| sort_descending!(mixins) }
        end
      end
    end
  end
end
