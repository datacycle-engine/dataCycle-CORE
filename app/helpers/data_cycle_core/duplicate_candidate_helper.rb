# frozen_string_literal: true

module DataCycleCore
  module DuplicateCandidateHelper
    def duplicate_score_tag(candidates)
      return if candidates.blank?

      candidates.sort_by! { |c| -c.score.to_i }
      tooltip = safe_join(
        candidates.map do |c|
          safe_join(["#{c.duplicate_module.model_name.human(count: 1, locale: active_ui_locale)}:", tag.b(c.score.to_i)], ' ')
        end,
        tag.br
      )

      tag.b(candidates.first.score.to_i, data: { dc_tooltip: tooltip })
    end
  end
end
