# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class DownloadAllowedByContentAndScope < Base
        attr_reader :subject, :scopes

        def initialize(subject, scopes = [:content])
          @scopes = Array.wrap(scopes).map(&:to_sym)
          @subject = subject
        end

        def include?(content, *_args)
          DataCycleCore::Feature::Download.allowed?(content, scopes)
        end

        def to_proc
          ->(*args) { include?(*args) }
        end

        private

        def to_restrictions(**)
          to_restriction(scopes: Array.wrap(scopes).map { |v| I18n.t("abilities.download_scopes.#{v}", locale:) }.join(', '))
        end
      end
    end
  end
end
