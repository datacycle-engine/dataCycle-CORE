# frozen_string_literal: true

Rails.application.configure do
  config.after_initialize do
    DataCycleCore.permissions_list = DataCycleCore::Abilities::PermissionsList.new

    DataCycleCore.permissions_list.add_permission(
      DataCycleCore::Abilities::Segments::UsersByRole.new(:super_admin),
      :can, :manage,
      DataCycleCore::Abilities::Segments::SubjectByConditions.new(
        [
          :dash_board,
          :backend,
          DataCycleCore::ClassificationTreeLabel,
          DataCycleCore::ClassificationAlias,
          DataCycleCore::StoredFilter,
          DataCycleCore::User,
          DataCycleCore::DataAttribute,
          DataCycleCore::Thing,
          DataCycleCore::WatchList,
          DataCycleCore::Thing::History
        ]
      )
    )
  end
end
