# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module Copyright
        class << self
          def copyright_notice(computed_parameters:, content:, **args)
            copyright_notice = []
            classification_copyright_notice = []
            cc_license = false

            computed_parameters.each do |computed_key, value|
              next if DataCycleCore::DataHashService.blank?(value)

              case content&.properties_for(computed_key)&.dig('type')
              when 'classification'
                if computed_key == 'universal_classifications' && classification_copyright_notice.blank?
                  # license_classifications = DataCycleCore::Classification.where(id: value).classification_aliases.includes(:classification_tree_label).where(classification_tree_labels: { name: content&.properties_for('license_classification')&.dig('tree_label') }).primary_classifications
                  license_classifications = DataCycleCore::Concept.where(classification_id: value).preload(:concept_scheme, mapped_inverse_concepts: :concept_scheme).to_a
                  license_classifications += license_classifications.flat_map(&:mapped_inverse_concepts)
                  license_classifications.select! { |c| c.concept_scheme.name == content&.properties_for('license_classification')&.dig('tree_label') }
                elsif computed_key != 'universal_classifications'
                  license_classifications = DataCycleCore::Concept.where(classification_id: value)
                end

                next if license_classifications.blank?

                # CreativeCommon https://creativecommons.org/
                # CC0 https://creativecommons.org/publicdomain/zero/1.0/
                cc_license = true if license_classifications.all? { |c| c.try(:uri)&.starts_with?('https://creativecommons.org/') }
                classification_copyright_notice.concat(license_classifications.pluck(:internal_name))
                break if license_classifications.any? { |c| c.try(:uri) == 'https://creativecommons.org/publicdomain/zero/1.0/' } && license_classifications.size == 1
              when 'linked'
                copyright_notice.push(DataCycleCore::Thing.where(id: value).filter_map { |c| I18n.with_locale(c.first_available_locale) { c.title.presence } }.join(', ').presence)
              when 'number'
                copyright_notice.push(value.presence&.to_i)
              else
                copyright_notice.push(value.presence)
              end
            end

            copyright_notice = copyright_notice.compact.presence&.join(' / ')
            copyright_notice = "#{classification_copyright_notice.compact.presence&.join(' ')}  #{copyright_notice}" if classification_copyright_notice.present?
            copyright_prefix = '(c)' unless args.dig(:computed_definition, 'compute', 'prefix_c') == false
            copyright_notice = "#{copyright_prefix} #{copyright_notice}" if cc_license.blank? && copyright_notice.present?
            copyright_notice
          end
        end
      end
    end
  end
end
