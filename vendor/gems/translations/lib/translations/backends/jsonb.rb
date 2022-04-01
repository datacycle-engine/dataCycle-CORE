# frozen_string_literal: true

module Translations
  module Backends
    module Jsonb
      extend Translations::Backend::OrmDelegator
    end
  end
end
