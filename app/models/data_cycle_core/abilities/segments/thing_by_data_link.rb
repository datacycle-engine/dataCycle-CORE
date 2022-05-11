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
          return false if session[:data_link_ids].blank?

          DataCycleCore::DataLink.where(id: session[:data_link_ids], permissions: 'write').valid.includes(:item).find_each do |link|
            release_partner_stage_id = DataCycleCore::Classification.includes(classification_aliases: :classification_tree_label).find_by(name: DataCycleCore::Feature::Releasable.get_stage('partner'), classification_aliases: { classification_tree_labels: { name: 'Release-Stati' } })&.id

            return link.item.watch_list_data_hashes.pluck(:hashable_id).include?(content.id) && content.release_status_id.presence&.ids&.include?(release_partner_stage_id) if DataCycleCore::Feature::Releasable.allowed?(content) && release_partner_stage_id.present? && link.item_type == 'DataCycleCore::WatchList'

            return link.item_id == content.id && content.release_status_id.presence&.ids&.include?(release_partner_stage_id) if DataCycleCore::Feature::Releasable.allowed?(content) && release_partner_stage_id.present?

            return link.item.watch_list_data_hashes.pluck(:hashable_id).include?(content.id) if link.item_type == 'DataCycleCore::WatchList'

            return link.item_id == content.id
          end

          false
        end

        def to_proc
          ->(*args) { include?(*args) }
        end
      end
    end
  end
end
