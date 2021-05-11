# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Validators
      class Slug < BasicValidator
        def validate(data, _template, _strict = false)
          text = DataCycleCore::MasterData::DataConverter.string_to_slug(data, @content)
          found = DataCycleCore::Thing::Translation.find_by(slug: text)
          return @error if found.blank? && text.present?

          if @content.blank?
            (@error[:error][@template_key] ||= []) << I18n.t(:slug, scope: [:validation, :errors], data: data, locale: DataCycleCore.ui_language) if text.present?
          elsif found.thing_id != @content.id || found.locale != I18n.locale.to_s
            (@error[:error][@template_key] ||= []) << I18n.t(:slug, scope: [:validation, :errors], data: data, locale: DataCycleCore.ui_language) if text.present?
          end
          @error
        end
      end
    end
  end
end
