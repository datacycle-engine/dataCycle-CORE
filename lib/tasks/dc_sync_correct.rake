# frozen_string_literal: true

namespace :dc do
  namespace :sync do
    desc 'fold duplicated weekday concepts into the one most contents already use'
    task fix_weekdays: :environment do
      puts 'cleanup weekdays:'

      ['Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag', 'Samstag', 'Sonntag'].each do |day|
        concepts = DataCycleCore::Concept
          .with_internal_name(day)
          .left_joins(:concept_contents)
          .group('concepts.id')
          .reorder(Arel.sql('COUNT(concept_contents.id) DESC'))
          .to_a

        puts "#{day}: #{concepts.size} concept(s)"
        next if concepts.size < 2

        main, *duplicates = concepts

        # merge_with moves the contents, the mappings, the polygons and the stored filter parameters
        # over and destroys the source - what this task used to do by hand, and got wrong.
        duplicates.each { |duplicate| duplicate.merge_with(main) }
      end
    end
  end
end
