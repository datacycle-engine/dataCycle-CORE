# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Validators
      class Embedded < BasicValidator
        def keywords
          ['min', 'max', 'classifications']
        end

        def validate(data, template)
          if blank?(data)
            (@error[:warning][@template_key] ||= []) << I18n.t(:no_data, scope: [:validation, :warnings], data: template['label'], locale: DataCycleCore.ui_language)
          elsif data.is_a?(::Array)
            check_data_array(data, template)
          elsif data.is_a?(::Hash)
            check_data_array([data], template)
          else
            (@error[:error][@template_key] ||= []) << I18n.t(:data_format_embedded, scope: [:validation, :errors], data: data, template: template['label'], locale: DataCycleCore.ui_language)
          end
          @error
        end

        private

        def check_data_array(data, template)
          # validate given validations
          if template.key?('validations')
            template['validations'].each_key do |key|
              if keywords.include?(key)
                method(key).call(data, template['validations'][key])
              else
                (@error[:error][@template_key] ||= []) << I18n.t(:keyword, scope: [:validation, :warnings], key: key, type: 'EmbeddedLinkArray', locale: DataCycleCore.ui_language)
              end
            end
          end

          # validate references
          embedded_template = DataCycleCore::Thing
            .find_by(template: true, template_name: template['template_name'])
          if template.blank? || embedded_template.blank?
            (@error[:error][@template_key] ||= []) << I18n.t(:no_template, scope: [:validation, :errors], name: 'things', locale: DataCycleCore.ui_language)
            return
          end
          data.each do |item|
            next if item.empty?
            if item.is_a?(::Hash)
              validator_object = DataCycleCore::MasterData::ValidateData.new
              merge_errors(validator_object.validate(item, embedded_template.schema))
            else
              (@error[:error][@template_key] ||= []) << I18n.t(:data_format_embedded, scope: [:validation, :errors], data: data, template: template['label'], locale: DataCycleCore.ui_language)
            end
          end
        end

        def classifications(data_hash, _template_hash)
          return if data_hash.blank? || DataCycleCore.features.dig(:publication_schedule, :classification_keys).blank?
          (@error[:error][@template_key] ||= []) << I18n.t(:classification_conflict, scope: [:validation, :errors], locale: DataCycleCore.ui_language) if data_hash.each { |d| d['id'] = SecureRandom.uuid if d['id'].blank? }.map { |x| data_hash.select { |y| (x != y) && DataCycleCore.features.dig(:publication_schedule, :classification_keys).map { |z| x[z].present? && y[z].present? ? (x[z] & y[z]) : [] }.all?(&:present?) } }.flatten.present?
        end

        # validate nil,"",[],[nil],[""],[{}] as blank.
        def blank?(data)
          return true if data.blank?
          if data.is_a?(::Array)
            return true if data.length == 1 && data[0].blank?
          end
          false
        end

        def min(data, value)
          (@error[:error][@template_key] ||= []) << I18n.t(:min_ref, scope: [:validation, :errors], data: data.size, value: value, locale: DataCycleCore.ui_language) if data.size < value
        end

        def max(data, value)
          (@error[:error][@template_key] ||= []) << I18n.t(:max_ref, scope: [:validation, :errors], data: data.size, value: value, locale: DataCycleCore.ui_language) if data.size > value
        end
      end
    end
  end
end
