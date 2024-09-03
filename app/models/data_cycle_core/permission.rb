# frozen_string_literal: true

module DataCycleCore
  class Permission
    include ActiveModel::Model

    attr_accessor :condition, :actions, :definition, :ability

    delegate :user, :session, to: :ability
    delegate :to_descriptions, to: :definition
    delegate :locale, to: :definition

    def translated_descriptions
      Array.wrap(to_descriptions).flat_map do |d|
        Array.wrap(actions).map do |a|
          data = d.clone
          data[:action] = I18n.t("abilities.actions.#{a}", locale:)
          data[:restrictions] = Array.wrap(data[:restrictions])
          data
        end
      end
    end
  end
end
