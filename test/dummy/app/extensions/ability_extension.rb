# frozen_string_literal: true

module AbilityExtension
  def load_abilities
    DataCycleCore::Abilities::PermissionsList.add_abilities_for_user(self)
  end
end

DataCycleCore::Ability.prepend(AbilityExtension)
