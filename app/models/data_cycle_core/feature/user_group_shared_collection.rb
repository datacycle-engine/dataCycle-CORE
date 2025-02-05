# frozen_string_literal: true

module DataCycleCore
  module Feature
    class UserGroupSharedCollection < Base
      class << self
        def attribute_keys(content = nil)
          Array.wrap(configuration(content)['attribute_keys']&.keys)
        end

        def whitelist(content = nil)
          whitelist = Array.wrap(configuration(content)['whitelist'])
          collections = []
          if whitelist.blank? || !whitelist.first.is_a?(String) # rubocop:disable Lint/EmptyConditionalBody
          elsif whitelist.first == '*' && whitelist.size == 1
            collections = DataCycleCore::Collection.where.not('name' => nil)
          else
            collections = DataCycleCore::Collection.where.not('name' => nil).where(id: whitelist.map { |collection| DataCycleCore::Collection.where(id: collection)&.first&.id || DataCycleCore::Collection.where(slug: collection)&.first&.id }.uniq)
          end

          collections.select { |c| c.name.present? && c.name != 'Meine Auswahl' }
        end
      end
    end
  end
end
