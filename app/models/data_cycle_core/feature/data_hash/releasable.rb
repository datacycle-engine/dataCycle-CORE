# frozen_string_literal: true

module DataCycleCore
  module Feature
    module DataHash
      module Releasable
        extend ActiveSupport::Concern

        included do
          before_save_data_hash :update_release_status, if: proc {
            finalize &&
              @current_user.present? &&
              (data_links.where(receiver_id: @current_user.id, permissions: 'write').present? ||
              watch_lists.includes(:data_links).where(data_links: { receiver_id: @current_user.id }).exists?)
          }
        end

        def update_release_status
          data_links.where(receiver_id: @current_user.id, permissions: 'write').update(permissions: 'read')

          review_classification_id = DataCycleCore::Classification.includes(classification_aliases: :classification_tree_label).where(name: DataCycleCore::Feature::Releasable.get_stage('review'), classification_aliases: { classification_tree_labels: { name: 'Release-Stati' } }).presence&.ids

          return unless DataCycleCore::Feature::Releasable.allowed?(self) && review_classification_id.present?

          @data_hash[DataCycleCore::Feature::Releasable.attribute_keys.first] = review_classification_id
        end
      end
    end
  end
end
