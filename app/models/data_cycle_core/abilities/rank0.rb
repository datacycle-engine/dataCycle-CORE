# frozen_string_literal: true

module DataCycleCore
  module Abilities
    class Rank0 < DataCycleCore::Ability
      def initialize(user, session = {})
        cached_tree_labels = Hash.new do |h, key|
          h[key] = DataCycleCore::ClassificationTreeLabel.find_by(name: key)
        end

<<<<<<< HEAD
        can [:show, :find], :object_browser
        can [:login, :renew_login, :reset_password], :user_api
        can :create_editable_links, DataCycleCore::DataLink
        can [:show, :index], DataCycleCore::Asset, creator_id: user.id, asset_content: { id: nil }
        can :copy_api_link, DataCycleCore::WatchList
=======
        can :update, DataCycleCore::User, id: user.id
        can [:show, :find], :object_browser
        can [:login, :renew_login, :reset_password, :confirm], :user_api
        can :create_editable_links, DataCycleCore::DataLink
        can [:show, :index], DataCycleCore::Asset, creator_id: user.id, asset_content: { id: nil }
        can :copy_api_link, DataCycleCore::WatchList, my_selection: false
>>>>>>> old/develop
        can :index, DataCycleCore::Role, rank: 0..user&.role&.rank.to_i
        can :create, DataCycleCore::Thing do |template, scope|
          scope == 'asset' && template&.creatable?(scope)
        end
        can :edit, DataCycleCore::DataAttribute
        can :update, DataCycleCore::DataAttribute do |attribute|
          if attribute.definition.dig('ui', 'edit', 'readonly')
            false
          elsif DataCycleCore::Feature::PublicationSchedule.allowed?(attribute.content)
            !(
              (attribute.key =~ Regexp.union(*DataCycleCore.features.dig(:publication_schedule, :classification_keys))) &&
              !DataCycleCore::Feature::PublicationSchedule.includes_attribute_key(attribute.content, attribute.key)
            )
          else
            (
              attribute.content.try(:external_source_id).blank? ||
              (
                DataCycleCore::Feature::Overlay.allowed?(attribute.content) &&
                DataCycleCore::Feature::Overlay.includes_attribute_key(attribute.content, attribute.key)
              ) ||
              attribute.definition.dig('global')
            )
          end
        end

        cannot :edit, DataCycleCore::DataAttribute do |attribute|
          attribute.definition.dig('ui', attribute.scope.to_s, 'disabled') == true ||
            (
              !DataCycleCore::Feature::Overlay.allowed?(attribute.content) &&
              DataCycleCore::Feature::Overlay.includes_attribute_key(attribute.content, attribute.key)
            ) ||
            (attribute.content.try(:external_source_id).blank? && DataCycleCore::Feature::Overlay.includes_attribute_key(attribute.content, attribute.key)) ||
            (
              attribute.definition.dig('tree_label').present? && cached_tree_labels[attribute.definition.dig('tree_label')]&.external_source_id.present? &&
              (cached_tree_labels[attribute.definition.dig('tree_label')]&.external_source_id != attribute.content.try(:external_source_id) && !attribute.definition.dig('global') && attribute.scope.to_s == 'edit')
            ) ||
            (attribute.definition.dig('external') && attribute.content.try(:external_source_id).blank? && attribute.scope.to_s == 'edit') ||
            (DataCycleCore::Feature::Releasable.attribute_keys(attribute.content).include?(attribute.key.attribute_name_from_key) && attribute.scope.to_s == 'show')
        end

        cannot :show, DataCycleCore::DataAttribute do |attribute|
          attribute.definition.dig('ui', attribute.scope.to_s, 'disabled') == true ||
            (
              !DataCycleCore::Feature::Overlay.allowed?(attribute.content) &&
              DataCycleCore::Feature::Overlay.includes_attribute_key(attribute.content, attribute.key)
            ) ||
            (attribute.content.try(:external_source_id).blank? && DataCycleCore::Feature::Overlay.includes_attribute_key(attribute.content, attribute.key)) ||
            (
              attribute.definition.dig('tree_label').present? && cached_tree_labels[attribute.definition.dig('tree_label')]&.external_source_id.present? &&
              (cached_tree_labels[attribute.definition.dig('tree_label')]&.external_source_id != attribute.content.try(:external_source_id) && !attribute.definition.dig('global') && attribute.scope.to_s == 'edit')
            ) ||
            (attribute.definition.dig('external') && attribute.content.try(:external_source_id).blank? && attribute.scope.to_s == 'edit') ||
            (DataCycleCore::Feature::Releasable.attribute_keys(attribute.content).include?(attribute.key.attribute_name_from_key) && attribute.scope.to_s == 'show')
        end

<<<<<<< HEAD
        DataCycleCore::DataLink.session_edit_links(session[:can_edit_ids]).each do |link|
          next unless link.is_valid?

=======
        if DataCycleCore::DataLink.where(id: session[:data_link_ids], item_type: 'DataCycleCore::StoredFilter').valid.exists?
          can [:read, :search, :classification_trees, :classification_tree, :permanent_advanced, :advanced], :backend
          can :advanced_filter, :backend do |_t, _k, v|
            v == 'fulltext_search'
          end
        end

        DataCycleCore::DataLink.where(id: session[:data_link_ids], permissions: 'write').valid.includes(:item).find_each do |link|
>>>>>>> old/develop
          release_partner_stage_id = DataCycleCore::Classification.includes(classification_aliases: :classification_tree_label).find_by(name: DataCycleCore::Feature::Releasable.get_stage('partner'), classification_aliases: { classification_tree_labels: { name: 'Release-Stati' } })&.id

          can [:update, :import], DataCycleCore::Thing do |content|
            if DataCycleCore::Feature::Releasable.allowed?(content) && release_partner_stage_id.present? && link.item_type == 'DataCycleCore::WatchList'
              link.item.watch_list_data_hashes.pluck(:hashable_id).include?(content.id) && content.release_status_id.presence&.ids&.include?(release_partner_stage_id)
            elsif DataCycleCore::Feature::Releasable.allowed?(content) && release_partner_stage_id.present?
              link.item_id == content.id && content.release_status_id.presence&.ids&.include?(release_partner_stage_id)
            elsif link.item_type == 'DataCycleCore::WatchList'
              link.item.watch_list_data_hashes.pluck(:hashable_id).include?(content.id)
            else
              link.item_id == content.id
            end
          end
        end

        can :print, DataCycleCore::Thing do |content|
          ['entity'].include?(content.schema['content_type'])
        end
        can :api, DataCycleCore::StoredFilter, api: true, user: user
        can :api, DataCycleCore::StoredFilter, ['api = ? AND ? = ANY(api_users)', true, user.id] do |sf|
          sf.api && sf.api_users&.include?(user.id)
        end
      end
    end
  end
end
