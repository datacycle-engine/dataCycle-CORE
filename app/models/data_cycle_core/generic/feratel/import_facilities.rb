# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Feratel
      module ImportFacilities
        def import_data(**options)
          raise NotImplementedError
        end

        # def import_data(**options)
        #   import_classifications(@source_type,
        #                          options.try(:[], :import).try(:[], :tree_label) || 'Feratel - Facilities',
        #                          method(:load_root_classifications).to_proc,
        #                          method(:load_child_classifications).to_proc,
        #                          method(:load_parent_classification_alias).to_proc,
        #                          method(:extract_data).to_proc,
        #                          **options)
        # end
        #
        # protected
        #
        # def load_root_classifications(locale)
        #   DataCycleCore::Generic::SourceType::FacilityGroup.where("dump.#{locale}.Name.Translation.Language": 'de')
        # end
        #
        # def load_child_classifications(parent_category_data, locale)
        #   if parent_category_data['GroupID']
        #     []
        #   else
        #     DataCycleCore::Generic::SourceType::Facility.where("dump.#{locale}.GroupID": parent_category_data['Id'])
        #   end
        # end
        #
        # def load_parent_classification_alias(raw_data)
        #   if raw_data['GroupID']
        #     DataCycleCore::Classification
        #       .find_by(external_source_id: external_source.id, external_key: raw_data['GroupID'])
        #       .try(:primary_classification_alias)
        #   else
        #     nil
        #   end
        # end
        #
        # def extract_data(raw_data)
        #   {
        #     external_id: raw_data['Id'],
        #     name: raw_data.dig('Name', 'Translation', 'text')
        #   }
        # end
      end
    end
  end
end
