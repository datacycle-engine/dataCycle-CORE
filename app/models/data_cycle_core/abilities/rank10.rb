# frozen_string_literal: true

module DataCycleCore
  module Abilities
    class Rank10 < DataCycleCore::Ability
      def initialize(user, _session = {})
        can [:read, :create, :update, :destroy], DataCycleCore::UserGroup
        can [:create_global, :create_api, :create_api_with_users], DataCycleCore::StoredFilter, user_id: user.id
        can [:merge_duplicates, :remove_lock, :translate], DataCycleCore::Thing

        # User Administraion
        can [:read, :create_user, :update, :destroy, :unlock, :generate_access_token, :set_role, :set_user_groups], DataCycleCore::User, role: { rank: 0..user&.role&.rank.to_i }

        can :clear_all, :cache
        can :clear, :cache

        # Contents
        can [:set_life_cycle, :view_life_cycle, :move_content], DataCycleCore::Thing

        can :destroy, DataCycleCore::Thing, external_source_id: nil

        # Advanced filter
        can :advanced_filter, :backend do |_t, _k, v|
          v != 'advanced_attributes'
        end

        # Sortable
        can :sortable, :backend

        # Classifications
        can :manage, [DataCycleCore::Classification, DataCycleCore::ClassificationTree], external_source_id: nil

        can :read, DataCycleCore::ClassificationTreeLabel, ['classification_tree_labels.visibility && ARRAY[?]::VARCHAR[]', ['classification_overview', 'classification_administration']] do |ctl|
          ctl.visibility&.intersection(['classification_overview', 'classification_administration'])&.any?
        end
        can [:download, :create, :edit], DataCycleCore::ClassificationTreeLabel
        can :update, DataCycleCore::ClassificationTreeLabel, external_source_id: nil, internal: false

        can [:create, :update, :download], DataCycleCore::ClassificationAlias, external_source_id: nil, internal: false
        can :map_classifications, DataCycleCore::ClassificationAlias, internal: false

        can :destroy, DataCycleCore::ClassificationTreeLabel, external_source_id: nil, internal: false, classification_aliases: { internal: false, external_source_id: nil }

        can :destroy, DataCycleCore::ClassificationAlias, external_source_id: nil, internal: false, sub_classification_alias: { internal: false, external_source_id: nil }

        # Downloads
        can :download, [DataCycleCore::Thing, DataCycleCore::WatchList, DataCycleCore::StoredFilter] do |content|
          DataCycleCore::Feature::Download.allowed?(content)
        end
        # collections
        can :download_zip, [DataCycleCore::Thing, DataCycleCore::WatchList, DataCycleCore::StoredFilter] do |content|
          DataCycleCore::Feature::Download.allowed?(content, [:archive, :zip])
        end
        can :download_indesign, [DataCycleCore::Thing, DataCycleCore::WatchList, DataCycleCore::StoredFilter] do |content|
          DataCycleCore::Feature::Download.allowed?(content, [:archive, :indesign])
        end

        # Reports
        can [:index, :download_report, :download_global_report], :report
        can :download_content_report, DataCycleCore::Thing do |content|
          DataCycleCore::Feature::ReportGenerator.allowed?(content)
        end
      end
    end
  end
end
