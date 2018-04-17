class Ability < DataCycleCore::Ability
  def initialize(user, _session = {})
    super

    return unless user && user&.has_rank?(0)
    can :create_in_objectbrowser, [DataCycleCore::Person, DataCycleCore::Organization, DataCycleCore::Place]

    can :show_history, DataCycleCore::StoredFilter
  end
end
