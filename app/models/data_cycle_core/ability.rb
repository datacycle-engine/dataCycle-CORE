module DataCycleCore
  class Ability
    include CanCan::Ability

    def initialize(user, session = {})
      alias_action :update, :destroy, to: :modify
      alias_action :create, :import, :read, :update, :create_user, :unlock, :validate_single_data, :history, :history_detail, to: :crud

      if user
        can :read, :all
        cannot :read, DataCycleCore::WatchList
        cannot :read, :backend
        can [:show, :find], :object_browser

        if user.has_rank?(0)
          DataCycleCore::DataLink.session_edit_links(session[:can_edit_ids]).each do |link|
            can [:update, :validate_single_data, :import], link.item_type.constantize, {id: link.item_id}
          end
          can :create_in_objectbrowser, [DataCycleCore::Person, DataCycleCore::CreativeWork, DataCycleCore::Place]
        end

        if user.has_rank?(1)
          can :read, :backend
          can :modify, DataCycleCore::User, id: user.id
          can :manage, DataCycleCore::WatchList, user_id: user.id
          can :subscribe, [DataCycleCore::Person, DataCycleCore::CreativeWork, DataCycleCore::Place]
        end

        if user.has_rank?(10)
          can :manage, [DataCycleCore::DataLink, DataCycleCore::Classification]
          can :crud,
            [
              DataCycleCore::User,
              DataCycleCore::UserGroup,
              DataCycleCore::Person,
              DataCycleCore::Place
            ]

          can :update_release_status, [DataCycleCore::Person, DataCycleCore::CreativeWork, DataCycleCore::Place]

          can :manage,
            [
              DataCycleCore::Classification,
              DataCycleCore::ClassificationTreeLabel,
              DataCycleCore::ClassificationTree,
              DataCycleCore::ClassificationAlias
            ],
            external_source_id: nil

          can :crud, DataCycleCore::CreativeWork do |creative_work|
            creative_work&.metadata&.dig('validation','permissions','read_write') != false
          end

          can [:set_role, :set_user_groups], DataCycleCore::User do |the_user|
            !the_user.has_rank?(user.role.rank) || user == the_user
          end
        end

        if user.has_rank?(10) && (user.email =~ /@pixelpoint\.at/ || user.email =~ /@datacycle\.at/)
          can :manage, :dash_board
          can :destroy, DataCycleCore::CreativeWork
        end

        can :edit, DataCycleCore::DataAttribute do |attribute|
          !attribute.options['readonly']
        end

        if !(user.email =~ /@pixelpoint\.at/ || user.email =~ /@datacycle\.at/)
          cannot :modify, DataCycleCore::User do |the_user|
            (the_user.role && the_user.role.rank == 0) || (the_user.has_rank?(user.role.try(:rank)) && the_user != user)
          end
        end
      end
    end
  end
end
