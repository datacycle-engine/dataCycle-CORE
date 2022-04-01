# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class DownloadAllowedByContentAndScope < Base
        attr_reader :subject, :scopes

        def initialize(subject, scopes = [])
          @scopes = Array.wrap(scopes).map(&:to_sym)
          @subject = subject
        end

        def include?(content, *_args)
          DataCycleCore::Feature::Download.allowed?(content, scopes)
        end

        def to_proc
          ->(*args) { include?(*args) }
        end
      end
    end
  end
end
