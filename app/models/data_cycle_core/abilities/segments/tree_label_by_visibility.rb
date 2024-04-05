# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class TreeLabelByVisibility < Base
        attr_reader :subject, :visibilities

        def initialize(*visibilities)
          @visibilities = Array.wrap(visibilities).flatten
          @subject = DataCycleCore::ClassificationTreeLabel
        end

        def scope
          ['classification_tree_labels.visibility && ARRAY[?]::VARCHAR[]', visibilities]
        end

        def include?(ctl, *_args)
          ctl.visibility&.intersection(visibilities)&.any?
        end

        def to_proc
          ->(*args) { include?(*args) }
        end

        private

        def to_restrictions(**)
          to_restriction(
            visibilities: Array.wrap(visibilities).map { |v| I18n.t("classification_visibilities.#{v}", locale:) }.join(', ')
          )
        end
      end
    end
  end
end
