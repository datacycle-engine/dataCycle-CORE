# frozen_string_literal: true

module DataCycleCore
  module Abilities
    class Rank10
      CONTENT_MODELS = DataCycleCore.content_tables.map { |table| "DataCycleCore::#{table.classify}".constantize }.freeze
      include CanCan::Ability

      def initialize(user, _session = {})
        can [:read, :create, :update, :destroy], DataCycleCore::UserGroup
        can :index, DataCycleCore::TextFile, creator_id: user.sibling_ids
        can [:create, :update], DataCycleCore::TextFile, creator_id: user.id

        can [:create_global, :create_api], DataCycleCore::StoredFilter, user_id: user.id

        # User Administraion
        can [:read, :create_user, :update, :destroy, :unlock, :generate_access_token, :set_role, :set_user_groups], DataCycleCore::User do |the_user|
          the_user == user || !the_user.has_rank?(user.role.rank)
        end

        # Contents
        can [:set_life_cycle, :move_content], CONTENT_MODELS

        can :destroy, CONTENT_MODELS do |content|
          content.try(:external_key).blank?
        end

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
      end
    end
  end
end