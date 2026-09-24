# frozen_string_literal: true

module DataCycleCore
  module OpenApi
    # Mixin for the stateless OpenAPI builder modules (paths, components,
    # schemas, …). `extend` it to get a `t` helper that delegates to
    # Translations so it is callable inside `module_function` definitions
    # (ambient locale set by DocumentBuilder). Keeps the builders DRY instead
    # of repeating the delegation in every module.
    module Localizable
      # Localized OpenAPI string (ambient locale set by DocumentBuilder).
      def t(key, **)
        DataCycleCore::OpenApi::Translations.t(key, **)
      end
    end
  end
end
