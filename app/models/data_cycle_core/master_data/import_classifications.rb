# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module ImportClassifications
      def self.import_all(_validation: true, classification_paths: nil)
        classification_paths ||= [DataCycleCore.default_template_paths, DataCycleCore.template_path].flatten.uniq.compact

        if classification_paths.blank?
          puts '###### classifications not found'
          return
        end

        merged_data_trees = {}

        classification_paths.each do |classification_path|
          file = classification_path + 'classifications.yml'
          next unless File.exist?(file)
          tree_array = YAML.load(File.open(file.to_s))
          merged_data_trees.deep_merge!(iterate_array(tree_array))
        end
        iterate_tree_hash(merged_data_trees)
      end

      def self.iterate_array(array)
        data = array.map { |item| item.is_a?(::String) ? { item => nil } : item }.reduce({}, :merge)
        data.map { |key, value|
          if value.blank? || value.is_a?(::String)
            { key => value }
          else
            { key => iterate_array(data[key]) }
          end
        }.reduce({}, :merge)
      end

      def self.iterate_tree_hash(trees_hash)
        trees_hash.each do |k, v|
          @label_id = get_label(k).id
          walk_tree_hash(v, nil)
        end
      end

      def self.walk_tree_hash(data_tree, parent)
        return nil if data_tree.blank?
        data_tree.each do |k, v|
          internal = false
          if k.starts_with?('$$') # '$$' prefix for interal classifications
            k = k[2..(k.length - 1)]
            internal = true
          end
          split_data = k.split('|').map(&:squish)
          name = split_data[0]
          description = split_data[1]
          current_id = save_data(name, parent, internal, description)

          walk_tree_hash(v, current_id) if v.is_a?(Hash)
        end
      end

      def self.save_data(data, parent, internal, description)
        find_alias = DataCycleCore::ClassificationAlias
          .joins(:classification_tree)
          .where(
            classification_aliases: { name: data },
            classification_trees: { classification_tree_label_id: @label_id, parent_classification_alias_id: parent }
          )

        if find_alias.count.positive?
          updated_data = find_alias.first
          updated_data.seen_at = Time.zone.now
          updated_data.internal = internal
          updated_data.description = description if description.present?
          updated_data.save
        else
          # new Alias, create respective tree-entry
          updated_data = DataCycleCore::ClassificationAlias.create(name: data, internal: internal, seen_at: Time.zone.now, description: description)
          DataCycleCore::ClassificationTree.find_or_create_by(
            classification_alias_id: updated_data.id,
            parent_classification_alias_id: parent,
            classification_tree_label_id: @label_id
          ) do |tree_entry|
            tree_entry.seen_at = Time.zone.now
          end
        end
        upsert_classification(data, updated_data.id, description)
        updated_data.id
      end

      def self.get_label(label)
        DataCycleCore::ClassificationTreeLabel.find_or_create_by(name: label, external_source_id: nil) do |label_data|
          label_data.seen_at = Time.zone.now
        end
      end

      def self.upsert_classification(data, classification_alias_id, description)
        find_classification = DataCycleCore::Classification
          .joins(classification_groups: [:classification_alias])
          .where(classification_aliases: { id: classification_alias_id })
        if find_classification.count < 1
          classification = DataCycleCore::Classification.create(name: data, external_source_id: nil, description: description) do |item|
            item.seen_at = Time.zone.now
          end
          DataCycleCore::ClassificationGroup.create(classification_id: classification.id, classification_alias_id: classification_alias_id, external_source_id: nil) do |group|
            group.seen_at = Time.zone.now
          end
        else
          classification = find_classification.first
          classification.name = data
          classification.description = description if description.present?
          classification.seen_at = Time.zone.now
          classification.save
        end
      end
    end
  end
end
