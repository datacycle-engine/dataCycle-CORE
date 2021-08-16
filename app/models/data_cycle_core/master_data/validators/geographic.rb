# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Validators
      class Geographic < BasicValidator
        # TODO: dummy evaluator for now
        def validate(data, template, _strict = false)
          if data.blank?
            # ignore
          elsif data.is_a?(::String)
            convert_2d = nil
            convert_3d = nil
            begin
              RGeo::Geographic.spherical_factory(srid: 4326, wkt_parser: { support_wkt12: true }, wkt_generator: { convert_case: :upper, tag_format: :wkt12 }).parse_wkt(data)
            rescue RGeo::Error::InvalidGeometry
              return (@error[:error][@template_key] ||= []) << { path: 'validation.errors.geo_no_linestring' }
            rescue RGeo::Error::ParseError
              convert_2d = {
                path: 'validation.errors.geo',
                substitutions: {
                  data: data,
                  template: template['label']
                }
              }
            end
            begin
              RGeo::Geographic.spherical_factory(srid: 4326, has_z_coordinate: true, wkt_parser: { support_wkt12: true }, wkt_generator: { convert_case: :upper, tag_format: :wkt12 }).parse_wkt(data)
            rescue RGeo::Error::InvalidGeometry
              return (@error[:error][@template_key] ||= []) << { path: 'validation.errors.geo_no_linestring' }
            rescue RGeo::Error::ParseError
              convert_3d = {
                path: 'validation.errors.geo',
                substitutions: {
                  data: data,
                  template: template['label']
                }
              }
            end
            (@error[:error][@template_key] ||= []) << convert_2d if convert_2d.present? && convert_3d.present?
          elsif data.methods.include?(:geometry_type)
            # all ok
          else
            (@error[:error][@template_key] ||= []) << {
              path: 'validation.errors.geo',
              substitutions: {
                data: data,
                template: template['label']
              }
            }
          end

          @error
        end
      end
    end
  end
end
