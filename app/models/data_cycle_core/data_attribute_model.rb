# frozen_string_literal: true

module DataCycleCore
  DataAttributeModel = Struct.new(:klass) do
    def human(**)
      I18n.t("activerecord.models.#{klass.name.underscore}", **)
    end
  end
end
