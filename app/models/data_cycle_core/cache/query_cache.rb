# frozen_string_literal: true

module DataCycleCore
  module Cache
    module QueryCache
      STD_TIME = 30.seconds
      LOGGING = true

      class << self
        def load_template(target_type, template_name)
          key = "#{target_type.table_name}/template/#{template_name}"
          log(key, "load_template(#{target_type.table_name}, #{template_name})")
          cache(key, STD_TIME, :load_template) do
            I18n.with_locale(:de) do
              target_type.find_by!(template: true, template_name: template_name)
            end
          end
        end

        def load_classifications_from_tree(tree_label, value)
          key = "classifications/#{tree_label}/classification/#{value}"
          log(key, "load_classifications_from_tree(#{tree_label}, #{value})")
          cache(key, STD_TIME, :load_classifications_from_tree) do
            DataCycleCore::Classification
              .joins(classification_groups: [classification_alias: [classification_tree: [:classification_tree_label]]])
              .where(classification_tree_labels: { name: tree_label }, classifications: { name: value })
          end
        end

        def check_classification_id_from_tree(tree_label, id)
          key = "classification_aliases/#{tree_label}/classification_alias/#{id}"
          log(key, "check_classification_id_from_tree(#{tree_label}, #{id})")
          cache(key, STD_TIME, :check_classification_id_from_tree) do
            DataCycleCore::Classification
              .joins(classification_groups: [classification_alias: [classification_tree: [:classification_tree_label]]])
              .where(classification_tree_labels: { name: tree_label }, classifications: { id: id })
          end
        end

        def load_classification_via_relations(join_relation, class_type_name, class_type, class_id_name, class_id, relation_name)
          key = "classifications/#{class_type_name}/#{class_id}/#{relation_name}/#{join_relation}"
          log(key, "load_classification_via_relations(#{join_relation}, #{class_type_name}, #{class_type}, #{class_id_name}, #{class_id}, #{relation_name})")
          cache(key, STD_TIME, :load_classification_via_relations) do
            DataCycleCore::Classification.joins(join_relation).where(join_relation => { class_type_name => class_type, class_id_name => class_id, relation: relation_name })
          end
        end

        def load_classification_relations(classification_object, where_hash)
          key = "classifications/#{where_hash.values.join('/')}"
          log(key, "load_classification_relation(#{classification_object.class}, #{where_hash})")
          cache(key, STD_TIME, :load_classification_relations) do
            classification_object.where(where_hash)
          end
        end

        def load_external_data(content_type, external_source_id, external_keys, debug = nil)
          key = "#{content_type.table_name}/#{external_source_id}/#{[external_keys].flatten.map(&:to_s).join('_')}"
          log(key, "load_external_data(#{content_type}(#{content_type.table_name}), #{external_source_id}, #{external_keys}, #{debug})")
          cache(key, STD_TIME, :load_external_data) do
            content_type.where(
              external_source_id: external_source_id,
              external_key: external_keys
            )
          end
        end

        def load_classification(name, external_source_id, external_key, debug = nil)
          key = "classifications/#{external_source_id}/#{external_key}/#{name}"
          log(key, "load_classification(#{name}, #{external_source_id}, #{external_key}, #{debug})")
          cache(key, STD_TIME, :load_classification) do
            DataCycleCore::Classification.where(
              name: name,
              external_source_id: external_source_id,
              external_key: external_key
            )
          end
        end

        def load_asset_relations(asset_relation_object, where_hash)
          key = "#{asset_relation_object.class_name}/#{where_hash.values.join('/')}"
          log(key, "load_asset_relations(#{asset_relation_object.class}, #{where_hash})")
          cache(key, STD_TIME, :load_asset_relations) do
            asset_relation_object.where(where_hash)
          end
        end

        def load_asset_via_relations(join_relation, class_id_name, class_id, relation_name)
          key = "assets/#{class_id}/#{relation_name}/#{join_relation}"
          log(key, "load_asset_relations(#{join_relation}, #{class_id_name}, #{class_id}, #{relation_name})")
          cache(key, STD_TIME, :load_asset_relations) do
            DataCycleCore::Asset.joins(join_relation).where(join_relation => { class_id_name => class_id, relation: relation_name })
          end
        end

        def load_user_by_email(email)
          user_object = DataCycleCore::User
          key = "#{user_object.table_name}/#{email}"
          log(key, "load_user_by_email(#{user_object.table_name}, #{email})")
          cache(key, STD_TIME, :load_user_by_email) do
            user_object.find_by(email: email)
          end
        end

        def cache(key, expires_in, method)
          Appsignal.instrument(method.to_s) do
            DataCycleCore.query_cache.fetch(key, expires_in: expires_in) do
              yield
            end
          end
        end

        def log(key, info)
          return unless LOGGING
          if DataCycleCore.query_cache.exist?(key)
            msg = 'Cache(hit)'
          else
            msg = 'Cache(miss)'
          end
          Rails.logger.info "---> #{msg} --> #{info}"
          Rails.logger.info "     #{DataCycleCore.query_cache.inspect}"
        end
      end
    end
  end
end
