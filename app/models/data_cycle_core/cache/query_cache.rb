# frozen_string_literal: true

module DataCycleCore
  module Cache
    module QueryCache
      STD_TIME = 30.seconds

      class << self
        def load_template(target_type, template_name)
          Rails.logger.info "***** #{Rails.cache.exist?("#{target_type.table_name}/template/#{template_name}")} --> load_template(#{target_type.table_name}, #{template_name})"
          Rails.cache.fetch("#{target_type.table_name}/template/#{template_name}", expires_in: STD_TIME) do
            I18n.with_locale(:de) do
              target_type.find_by!(template: true, template_name: template_name)
            end
          end
        end

        def load_classifications_from_tree(tree_label, value)
          Rails.logger.info "***** #{Rails.cache.exist?("classifications/#{tree_label}/classification/#{value}")} --> load_classifications_from_tree(#{tree_label}, #{value})"
          Rails.cache.fetch("classifications/#{tree_label}/classification/#{value}", expires_in: STD_TIME) do
            DataCycleCore::Classification
              .joins(classification_groups: [classification_alias: [classification_tree: [:classification_tree_label]]])
              .where(classification_tree_labels: { name: tree_label }, classifications: { name: value })
          end
        end

        def check_classification_id_from_tree(tree_label, id)
          Rails.logger.info "***** #{Rails.cache.exist?("classification_aliases/#{tree_label}/classification_alias/#{id}")} --> check_classification_id_from_tree(#{tree_label}, #{id})"
          Rails.cache.fetch("classification_aliases/#{tree_label}/classification_alias/#{id}", expires_in: STD_TIME) do
            DataCycleCore::Classification
              .joins(classification_groups: [classification_alias: [classification_tree: [:classification_tree_label]]])
              .where(classification_tree_labels: { name: tree_label }, classifications: { id: id })
          end
        end

        def load_classification_relations(join_relation, class_type_name, class_type, class_id_name, class_id, relation_name)
          Rails.logger.info "***** #{Rails.cache.exist?("classifications/#{class_type_name}/#{class_id}/#{relation_name}/#{join_relation}")} --> load_classification_relations(#{join_relation}, #{class_type_name}, #{class_type}, #{class_id_name}, #{class_id}, #{relation_name})"
          Rails.cache.fetch("classifications/#{class_type_name}/#{class_id}/#{relation_name}/#{join_relation}", expires_in: STD_TIME) do
            DataCycleCore::Classification.joins(join_relation).where(join_relation => { class_type_name => class_type, class_id_name => class_id, relation: relation_name })
          end
        end

        def load_asset_relations(join_relation, class_id_name, class_id, relation_name)
          Rails.logger.info "***** #{Rails.cache.exist?("assets/#{class_id}/#{relation_name}/#{join_relation}")} --> load_asset_relations(#{join_relation}, #{class_id_name}, #{class_id}, #{relation_name})"
          Rails.cache.fetch("assets/#{class_id}/#{relation_name}/#{join_relation}", expires_in: STD_TIME) do
            DataCycleCore::Asset.joins(join_relation).where(join_relation => { class_id_name => class_id, relation: relation_name })
          end
        end

        def load_external_data(content_type, external_source_id, external_keys, debug = nil)
          Rails.logger.info "***** #{Rails.cache.exist?("#{content_type.table_name}/#{external_source_id}/#{[external_keys].flatten.map(&:to_s).join('_')}")} --> load_external_data(#{content_type}(#{content_type.table_name}), #{external_source_id}, #{external_keys}, #{debug})"
          Rails.cache.fetch("#{content_type.table_name}/#{external_source_id}/#{[external_keys].flatten.map(&:to_s).join('_')}", expires_in: STD_TIME) do
            content_type.where(
              external_source_id: external_source_id,
              external_key: external_keys
            )
          end
        end

        def load_classification(name, external_source_id, external_key, debug = nil)
          Rails.logger.info "***** #{Rails.cache.exist?("classifications/#{external_source_id}/#{external_key}/#{name}")} --> load_classification(#{name}, #{external_source_id}, #{external_key}, #{debug})"
          Rails.cache.fetch("classifications/#{external_source_id}/#{external_key}/#{name}", expires_in: STD_TIME) do
            DataCycleCore::Classification.where(
              name: name,
              external_source_id: external_source_id,
              external_key: external_key
            )
          end
        end
      end
    end
  end
end
