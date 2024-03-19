# frozen_string_literal: true

module DataCycleCore
  class Permission
    include ActiveModel::Model

    attr_accessor :condition, :actions, :definition, :ability

    delegate :to_descriptions, to: :definition
    delegate :locale, to: :definition

    def initialize(*args, definition:, ability:, **keyword_args)
      definition.instance_variable_set(:@user, ability.user)
      definition.instance_variable_set(:@session, ability.session)

      super
    end

    def translated_descriptions
      Array.wrap(to_descriptions).flat_map do |d|
        Array.wrap(actions).map do |a|
          d[:action] = I18n.t("abilities.actions.#{a}", locale:)
          d[:restrictions] = Array.wrap(d[:restrictions])
          d
        end
      end
    end
  end
end
