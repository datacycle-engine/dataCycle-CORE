# frozen_string_literal: true

module DataCycleCore
  # Hands the locales of a content on to the contents inheriting them through a link, after that
  # content gained a translation. See DataCycleCore::Feature::LocaleInheritance.
  class LocaleInheritanceJob < UniqueApplicationJob
    queue_as :cache_invalidation
    queue_with_priority 12
    # keyed by the source: one run covers many inheriting contents, so there is no recipient to be
    # unique by. Two sources handing a locale to the same recipient at once is left to
    # #inherit_missing_locales, which logs the loser per locale instead of failing the job
    limits_concurrency key: ->(*args) { args[0] }

    # @param id [String] id of the content whose locales are inherited
    # @return [void]
    def perform(id)
      content = DataCycleCore::Thing.find_by(id:)
      return if content.nil?

      DataCycleCore::Feature::LocaleInheritance.inheriting_things(content).find_each(&:inherit_missing_locales)
    end
  end
end
