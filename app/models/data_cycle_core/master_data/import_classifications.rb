# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module ImportClassifications
      def self.import_all(_validation: true, classification_paths: nil)
        classification_paths ||= [DataCycleCore.default_template_paths, DataCycleCore.template_path].flatten.uniq.compact

        return puts('###### classifications not found') if classification_paths.blank?

        merged_data_trees = {}
        inhaltstypen_trees = []

        classification_paths.each do |classification_path|
          file = classification_path + 'classifications.yml'
          next unless File.exist?(file)
          tree_array = YAML.safe_load(File.open(file.to_s), permitted_classes: [Symbol])
          tree_hash = iterate_array(tree_array)
          merged_data_trees, inhaltstypen_trees = merge_trees(merged_data_trees, tree_hash, inhaltstypen_trees)
        end

        return_data = iterate_tree_hash(merged_data_trees)
        inhaltstypen_trees.each do |inhaltstypen_tree|
          return_data.merge!(iterate_tree_hash(inhaltstypen_tree, false))
        end
        check_features
        return_data
      end

      def self.merge_trees(merged_hash, tree, inhaltstypen_trees)
        tree.select { |k, _| k.exclude?('Inhaltstypen') }.each do |key, sub_tree|
          old_hash = merged_hash.select { |k, _| k.split('|').first.squish == key.split('|').first.squish }
          merged_hash.delete(old_hash&.keys&.first)

          merged_hash[key] = sub_tree
        end

        return merged_hash, inhaltstypen_trees.push(tree.select { |k, _| k.include?('Inhaltstypen') })
      end

      def self.iterate_array(array)
        return {} if array.blank?
        data = array.map { |item| item.is_a?(::String) ? { item => nil } : item }.reduce({}, :merge)
        data.map { |key, value|
          if value.blank? || value.is_a?(::String)
            { key => value }
          else
            { key => iterate_array(data[key]) }
          end
        }.reduce({}, :merge)
      end

      def self.iterate_tree_hash(trees_hash, allow_duplicates = true)
        trees_hash.each do |k, v|
          walk_tree_hash(v, nil, get_label(k).id, allow_duplicates)
        end
      end

      def self.walk_tree_hash(data_tree, parent, label_id, allow_duplicates = true)
        # data format> [$$]name[ | description]
        return nil if data_tree.blank?
        data_tree.each do |k, v|
          internal = false
          if k.starts_with?('$$') # '$$' prefix for interal classifications
            k = k[2..-1]
            internal = true
          end
          # extract uri
          split_data = k.split('**').map(&:squish)
          uri = split_data[1]
          # extract description
          split_data = split_data[0].split('|').map(&:squish)
          name = split_data[0]
          description = split_data[1]
          current_alias = save_data(name, parent, internal, description, uri, label_id, allow_duplicates)

          walk_tree_hash(v, current_alias, label_id, allow_duplicates) if v.is_a?(Hash)
        end
      end

      def self.save_data(data, parent, internal, description, uri, label_id, allow_duplicates = true)
        find_alias = DataCycleCore::ClassificationAlias
          .joins(:classification_tree)
          .find_by(
            name: data,
            classification_trees: {
              classification_tree_label_id: label_id
            }.merge(allow_duplicates ? { parent_classification_alias_id: parent.try(:id) } : {})
          )

        puts "WARNING: Duplicate ClassificationAlias '#{"#{parent&.internal_name} -> " unless parent.nil?}#{data}' found, check classification.yml" if !allow_duplicates && find_alias.present? && find_alias&.parent_classification_alias&.id != parent&.id

        if find_alias.present?
          updated_data = find_alias
          update_hash = { seen_at: Time.zone.now, internal:, description: description || updated_data.description, uri: uri || updated_data.uri }
          updated_data.classification_tree&.update(parent_classification_alias_id: parent&.id)
          updated_data.update(update_hash)
        else
          # new Alias, create respective tree-entry
          updated_data = DataCycleCore::ClassificationAlias.create(name: data, internal:, seen_at: Time.zone.now, description:, uri:)

          DataCycleCore::ClassificationTree.create(
            classification_alias_id: updated_data.id,
            parent_classification_alias_id: parent&.id,
            classification_tree_label_id: label_id,
            seen_at: Time.zone.now
          )
        end

        upsert_classification(data, updated_data.id, description, uri)
        updated_data
      end

      def self.get_label(label)
        internal = false
        if label.starts_with?('$$') # '$$' prefix for interal classifications
          label = label[2..-1]
          internal = true
        end

        split_data = label.split('|').map(&:squish)
        label = split_data[0]
        visibility = split_data[1] == 'all' ? DataCycleCore.default_classification_visibilities : (split_data[1]&.split(',')&.map(&:squish) || [])

        DataCycleCore::ClassificationTreeLabel.find_or_create_by(name: label) do |label_data|
          label_data.seen_at = Time.zone.now
          label_data.internal = internal
          label_data.visibility = visibility
        end
      end

      def self.upsert_classification(data, classification_alias_id, description, uri)
        find_classification = DataCycleCore::Classification
          .joins(classification_groups: [:classification_alias])
          .where(classification_aliases: { id: classification_alias_id })
        if find_classification.empty?
          classification = DataCycleCore::Classification.create(name: data, external_source_id: nil, description:, uri:) do |item|
            item.seen_at = Time.zone.now
          end
          DataCycleCore::ClassificationGroup.create(classification_id: classification.id, classification_alias_id:, external_source_id: nil) do |group|
            group.seen_at = Time.zone.now
          end
        else
          classification = find_classification.first
          update_hash = { name: data, seen_at: Time.zone.now, description: description || classification.description, uri: uri || classification.uri }
          classification.update(update_hash)
        end
      end

      def self.updated_classification_statistics(timestamp = Time.zone.now)
        classifications = {}
        DataCycleCore::ClassificationAlias.for_tree('Inhaltstypen').where('classification_aliases.seen_at < ?', timestamp.utc.to_s(:long_usec))
          .where(internal: true).where.not(seen_at: nil).find_each do |classification|
            classifications[classification.internal_name] = {
              seen_at: classification.seen_at,
              count: classification.linked_contents.count
            }
          end
        classifications
          .to_a
          .sort_by { |item| item[1][:seen_at] }
          .reduce({}) { |aggregate, item| aggregate.merge({ item[0] => item[1] }) }
      end

      def self.check_features
        return unless DataCycleCore::Feature::AutoTagging.enabled?

        tree_name = DataCycleCore.features.dig(:auto_tagging, :tree_label) || 'Cloud Vision - Tags'
        tree_label = DataCycleCore::ClassificationTreeLabel.find_by(name: tree_name, external_source_id: nil)
        external_source_name = DataCycleCore.features.dig(:auto_tagging, :external_source) || 'Google Cloud Vision'
        return if tree_label.blank? || external_source_name.blank?

        external_source_id = DataCycleCore::ExternalSystem.find_by(name: external_source_name)&.id
        return if external_source_id.blank?

        tree_label.external_source_id = external_source_id
        tree_label.save
        DataCycleCore::ClassificationAlias.for_tree(tree_name).update_all(external_source_id:)
      end
    end
  end
end
