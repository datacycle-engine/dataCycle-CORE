module DataCycleCore
  module Abilities
    class Rank0Ability
      CONTENT_MODELS = DataCycleCore.content_tables.map { |table| "DataCycleCore::#{table.classify}".constantize }.freeze
      include CanCan::Ability

      def initialize(_user, session = {})
        can [:show, :find], :object_browser

        can :edit, DataCycleCore::DataAttribute do |attribute|
          (
            attribute.content.try(:external_key).blank? ||
            (
              attribute.content&.schema&.dig('features', 'overlay').present? &&
              (attribute.key.scan(/\[(.*?)\]/).flatten & attribute.content.schema.dig('features', 'overlay')).size.nonzero?
            )
          )
        end

        DataCycleCore::DataLink.session_edit_links(session[:can_edit_ids]).each do |link|
          if link.is_valid? && link.item_type == 'DataCycleCore::WatchList'
            can [:update, :validate, :validate_single_data, :import], CONTENT_MODELS do |content|
              if content.try(:schema)&.dig('releasable') && DataCycleCore::Release.find_by(release_code: DataCycleCore.release_codes[:partner]).present?
                link.item.watch_list_data_hashes.pluck(:hashable_id).include?(content.id) && content.release_id == DataCycleCore::Release.find_by(release_code: DataCycleCore.release_codes[:partner]).id
              else
                link.item.watch_list_data_hashes.pluck(:hashable_id).include?(content.id)
              end
            end
          elsif link.is_valid?
            can [:update, :validate, :validate_single_data, :import], link.item_type.constantize, id: link.item_id
          end
        end

        can :print, CONTENT_MODELS do |content|
          ['entity'].include?(content.schema['content_type'])
        end
      end
    end
  end
end
