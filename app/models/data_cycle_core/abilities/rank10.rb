# frozen_string_literal: true

module DataCycleCore
  module Abilities
    class Rank10 < DataCycleCore::Ability
      def initialize(user, _session = {})
        can [:read, :create, :update, :destroy], DataCycleCore::UserGroup
        can [:create_global, :create_api], DataCycleCore::StoredFilter, user_id: user.id
        can :merge_duplicates, DataCycleCore::Thing

        # User Administraion
        can [:read, :create_user, :update, :destroy, :unlock, :generate_access_token, :set_role, :set_user_groups], DataCycleCore::User, role: { rank: 0..user&.role&.rank.to_i }

        # Contents
        can [:set_life_cycle, :move_content], DataCycleCore::Thing

        can :destroy, DataCycleCore::Thing do |content|
          content.try(:external_key).blank?
        end

        # Advanced filter
        can :advanced_filter, :backend

        # Classifications
        can :manage, [DataCycleCore::Classification, DataCycleCore::ClassificationTree], external_source_id: nil
        can [:read, :download], DataCycleCore::ClassificationTreeLabel
        can [:create, :update, :download], [DataCycleCore::ClassificationTreeLabel, DataCycleCore::ClassificationAlias], external_source_id: nil, internal: false

        can :map_classifications, DataCycleCore::ClassificationAlias
        can :destroy, DataCycleCore::ClassificationTreeLabel do |c|
          c.external_source_id.nil? && !c.internal && !c.classification_aliases&.any?(&:internal) && !c.classification_aliases&.any?(&:external_source_id)
        end
        can :destroy, DataCycleCore::ClassificationAlias do |c|
          c.external_source_id.nil? && !c.internal && !c.sub_classification_alias&.any?(&:internal) && !c.sub_classification_alias&.any?(&:external_source_id)
        end
        can :download, DataCycleCore::Thing do |content|
          DataCycleCore::Feature::Download.allowed?(content)
        end
      end
    end
  end
end
