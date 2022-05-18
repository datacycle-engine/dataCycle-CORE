# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class ThingByDataLink < Base
        attr_reader :subject

        def initialize
          @subject = DataCycleCore::Thing
        end

        def include?(content, *_args)
<<<<<<< HEAD
          return false if session[:can_edit_ids].blank?

          DataCycleCore::DataLink.session_edit_links(session[:can_edit_ids]).each do |link|
            next unless link.is_valid?

            release_partner_stage_id = DataCycleCore::Classification.includes(classification_aliases: :classification_tree_label).find_by(name: DataCycleCore::Feature::Releasable.get_stage('partner'), classification_aliases: { classification_tree_labels: { name: 'Release-Stati' } })&.id

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
=======
          return false if session[:data_link_ids].blank?

          DataCycleCore::DataLink.where(id: session[:data_link_ids], permissions: 'write').valid.includes(:item).find_each do |link|
            release_partner_stage_id = DataCycleCore::Classification.includes(classification_aliases: :classification_tree_label).find_by(name: DataCycleCore::Feature::Releasable.get_stage('partner'), classification_aliases: { classification_tree_labels: { name: 'Release-Stati' } })&.id

            return link.item.watch_list_data_hashes.pluck(:hashable_id).include?(content.id) && content.release_status_id.presence&.ids&.include?(release_partner_stage_id) if DataCycleCore::Feature::Releasable.allowed?(content) && release_partner_stage_id.present? && link.item_type == 'DataCycleCore::WatchList'

            return link.item_id == content.id && content.release_status_id.presence&.ids&.include?(release_partner_stage_id) if DataCycleCore::Feature::Releasable.allowed?(content) && release_partner_stage_id.present?

            return link.item.watch_list_data_hashes.pluck(:hashable_id).include?(content.id) if link.item_type == 'DataCycleCore::WatchList'

            return link.item_id == content.id
          end

          false
>>>>>>> old/develop
        end

        def to_proc
          ->(*args) { include?(*args) }
        end
      end
    end
  end
end
