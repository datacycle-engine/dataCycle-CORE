# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module ImportClassifications
      def self.import(filename)
        data_trees = YAML.load(File.open(filename))
        iterate_tree_array(data_trees)
      rescue StandardError => e
        puts "could not access the file: #{filename}"
        puts e.message
        puts e.backtrace
      end

      def self.iterate_tree_array(trees_array)
        trees_array.each do |item|
          @label_id = get_label(item.keys.first).id
          walk_tree(item[item.keys.first], nil)
        end
      end

      def self.walk_tree(data_tree, parent)
        return nil if data_tree.blank?
        data_tree.each do |data|
          internal = false
          if data.is_a?(String)
            split_data = data.split('|').map(&:squish)
            data = split_data[0]
            description = split_data[1]
            if data.starts_with?('$$')            # '$$' prefix for interal classifications
              data = data[2..(data.length - 1)]
              internal = true
            end
            save_data(data, parent, internal, description)
          elsif data.is_a?(Hash)
            parent_name = data.keys.first
            split_data = parent_name.split('|').map(&:squish)
            parent_name = split_data[0]
            description = split_data[1]
            if data.keys.first.starts_with?('$$') # '$$' prefix for interal classifications
              parent_name = data.keys.first[2..(data.keys.first.length - 1)]
              internal = true
            end
            parent_id = save_data(parent_name, parent, internal, description)
            walk_tree(data[data.keys.first], parent_id)
          end
        end
      end

      def self.save_data(data, parent, internal, description)
        if parent.nil?
          find_alias = DataCycleCore::ClassificationAlias
            .joins(:classification_tree)
            .where('classification_trees.classification_tree_label_id = ?', @label_id)
            .where('classification_aliases.name = ?', data)
            .where('classification_trees.parent_classification_alias_id is NULL')
        else
          find_alias = DataCycleCore::ClassificationAlias
            .joins(:classification_tree)
            .where('classification_trees.classification_tree_label_id = ?', @label_id)
            .where('classification_aliases.name = ?', data)
            .where('classification_trees.parent_classification_alias_id = ?', parent)
        end
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
          .where('classification_aliases.id = ? ', classification_alias_id)
          .where('classification_aliases.name = ? ', data)
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
