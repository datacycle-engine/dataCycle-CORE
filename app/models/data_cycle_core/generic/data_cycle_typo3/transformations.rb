# frozen_string_literal: true

module DataCycleCore
  module Generic
    module DataCycleTypo3
      module Transformations
        def self.t(*args)
          DataCycleCore::Generic::Common::Functions[*args]
        end

        def self.to_webpage
          t(:stringify_keys)
          .>> t(:rename_keys, { 'uid' => 'external_key', 'alternativeHeadline' => 'alternative_headline' })
          .>> t(:map_value, 'external_key', ->(s) { s&.to_s })
          .>> t(:add_field, 'date_created', ->(s) { Time.zone.at(s.dig('createdAt')) })
          .>> t(:add_field, 'date_modified', ->(s) { Time.zone.at(s.dig('updatedAt')) })
          .>> t(:universal_classifications, ->(s) { [DataCycleCore::ClassificationAlias.classification_for_tree_with_name('Website Status', s['status'].strip)] })
          .>> t(:universal_classifications, ->(s) { [DataCycleCore::ClassificationAlias.classification_for_tree_with_name('Website Identifiers', s['siteIdentifier'].strip)] })
          .>> t(:strip_all)
        end

        def self.to_website
          t(:stringify_keys)
          .>> t(:rename_keys, { 'uid' => 'external_key', 'alternativeHeadline' => 'alternative_headline' })
          .>> t(:map_value, 'external_key', ->(s) { s&.to_s })
          .>> t(:add_field, 'date_created', ->(s) { Time.zone.at(s.dig('createdAt')) })
          .>> t(:add_field, 'date_modified', ->(s) { Time.zone.at(s.dig('updatedAt')) })
          .>> t(:universal_classifications, ->(s) { [DataCycleCore::ClassificationAlias.classification_for_tree_with_name('Website Status', s['status'].strip)] })
          .>> t(:universal_classifications, ->(s) { [DataCycleCore::ClassificationAlias.classification_for_tree_with_name('Website Identifiers', s['siteIdentifier'].strip)] })
          .>> t(:strip_all)
        end
      end
    end
  end
end
