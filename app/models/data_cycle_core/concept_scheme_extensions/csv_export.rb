# frozen_string_literal: true

require 'csv'

module DataCycleCore
  module ConceptSchemeExtensions
    # The four CSV shapes the concept administration offers: the scheme itself, an empty mapping
    # template, and the mappings in either direction.
    module CsvExport
      extend ActiveSupport::Concern

      MAPPING_CSV_HEADER = ['Pfad zur Klassifizierung', 'Pfad zu gemappter Klassifizierung'].freeze

      # Indented by depth, one column per level, the scheme's own name in the first. A concept's
      # ancestors are the concepts above it (see Concept#ancestors), so the scheme's own row is the
      # +1 that keeps a root one column in.
      def to_csv(include_contents: false)
        CSV.generate do |csv|
          csv << [name]
          concepts.includes(:concept_path).sort_by(&:full_path).each do |concept|
            csv << (Array.new(concept.ancestors.count + 1) + [concept.name])

            next unless include_contents

            concept.assigned_things.includes(:translations).find_each do |content|
              content&.translations&.each do |content_translation|
                row = Array.new(concept.ancestors.count + 2)
                row += [
                  content.template_name,
                  content_translation.locale,
                  content_translation.content&.dig('name')
                ]
                csv << row
              end
            end
          end
        end
      end

      def to_csv_for_mappings
        CSV.generate do |csv|
          csv << MAPPING_CSV_HEADER
          concepts.includes(:concept_path).map(&:full_path).sort.each do |fp|
            csv << [fp, nil]
          end
        end
      end

      def to_csv_with_mappings
        mapping_csv(:mapped_concepts) { |concept, mapped| [concept.full_path, mapped.full_path] }
      end

      def to_csv_with_inverse_mappings
        mapping_csv(:mapped_inverse_concepts) { |concept, mapped| [mapped.full_path, concept.full_path] }
      end

      private

      def mapping_csv(association)
        CSV.generate do |csv|
          csv << MAPPING_CSV_HEADER
          concepts
            .includes(:concept_path, association => :concept_path)
            .reorder(nil)
            .order('array_reverse(concept_paths.full_path_names) ASC')
            .references(:concept_path)
            .find_each do |concept|
              concept.public_send(association).each { |mapped| csv << yield(concept, mapped) }
            end
        end
      end
    end
  end
end
