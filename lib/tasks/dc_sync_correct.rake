# frozen_string_literal: true

namespace :dc do
  namespace :sync do
    desc 'output template names and frequency in Thing and Thing::History'
    task fix_weekdays: :environment do
      puts 'cleanup weekdays:'
      ['Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag', 'Samstag', 'Sonntag'].each do |day|
        puts "#{day}..."

        # get the classification with the most things attached to it
        main_classification_id = DataCycleCore::Classification
          .where(name: day, deleted_at: nil)
          .joins(:classification_contents)
          .select('classifications.id, count(classification_contents.id) as size')
          .group('classifications.id')
          .order('size DESC')
          .first
          .id
        main_classification_alias_id = DataCycleCore::Classification.find(main_classification_id).primary_classification_alias.id
        unwanted_classification_ids = DataCycleCore::Classification.where(name: day).where.not(id: main_classification_id).ids
        unwanted_classification_alias_ids = DataCycleCore::ClassificationAlias.where(internal_name: day).where.not(id: main_classification_alias_id).ids

        # move all thing relations to the appropriate classification
        DataCycleCore::ClassificationContent.where(classification_id: unwanted_classification_ids).update_all(classification_id: main_classification_id)

        # cleanup
        DataCycleCore::ClassificationTree.where(classification_alias_id: unwanted_classification_alias_ids).delete_all!
        DataCycleCore::ClassificationGroup.where(classification_alias_id: unwanted_classification_alias_ids).delete_all!
        DataCycleCore::ClassificationAlias.where(id: unwanted_classification_alias_ids).delete_all!
        DataCycleCore::Classification.where(id: unwanted_classification_ids).delete_all!
      end
    end
  end
end
