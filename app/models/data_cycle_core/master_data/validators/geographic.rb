# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Validators
      class Geographic < BasicValidator
        # TODO: dummy evaluator for now
        def validate(data, template)
          if data.blank?
            (@error[:warning][@template_key] ||= []) << I18n.t(:no_data, scope: [:validation, :warnings], data: template['label'], locale: DataCycleCore.ui_language)
          elsif data.is_a?(::String)
            convert_2d = nil
            convert_3d = nil
            begin
              RGeo::Geographic.spherical_factory(srid: 4326).parse_wkt(data)
            rescue RGeo::Error::ParseError
              convert_2d = I18n.t(:geo, scope: [:validation, :errors], data: data, template: template['label'], locale: DataCycleCore.ui_language)
            end
            begin
              RGeo::Geographic.spherical_factory(srid: 4326, has_z_coordinate: true).parse_wkt(data)
            rescue RGeo::Error::ParseError
              convert_3d = I18n.t(:geo, scope: [:validation, :errors], data: data, template: template['label'], locale: DataCycleCore.ui_language)
            end
            (@error[:error][@template_key] ||= []) << convert_2d if convert_2d.present? && convert_3d.present?
          elsif data.methods.include?(:geometry_type)
            # all ok
          else
            (@error[:error][@template_key] ||= []) << I18n.t(:geo, scope: [:validation, :errors], data: data, template: template['label'], locale: DataCycleCore.ui_language)
          end
          @error
        end
      end
    end
  end
end
