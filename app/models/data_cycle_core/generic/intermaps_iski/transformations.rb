# frozen_string_literal: true

module DataCycleCore
  module Generic
    module IntermapsIski
      module Transformations
        def self.t(*args)
          DataCycleCore::Generic::Common::Functions[*args]
        end

        def self.to_lift(external_source_id)
          t(:rename_keys, { 'id' => 'external_key' })
          .>> t(:map_value, 'external_key', ->(v) { "IntermapsIski - Lift - #{v}" })
          .>> t(:add_field, 'ski_lift_type', ->(s) { lift_types[s.dig('type')] })
          .>> t(:universal_classifications, ->(s) { DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('Intermaps-iSKI - Lift Typen', s.dig('type')) })
          .>> t(:add_field, 'man_per_t', ->(s) { capacity[s.dig('type')] })
          .>> t(:add_field, 'ski_lift_status', ->(s) { opening_status[s.dig('status')] })
          .>> t(:add_field, 'snow_resort', ->(s) { DataCycleCore::Thing.find_by(external_source_id: external_source_id, external_key: external_key_prefix + s.dig('snow_resort_id').to_s)&.id })
        end

        def self.to_slope(external_source_id)
          t(:rename_keys, { 'id' => 'external_key' })
          .>> t(:map_value, 'external_key', ->(v) { "IntermapsIski - Piste - #{v}" })
          .>> t(:add_field, 'ski_slope_type', ->(s) { slope_types[s.dig('type')] })
          .>> t(:add_field, 'ski_lift_status', ->(s) { opening_status[s.dig('status')] })
          .>> t(:add_field, 'ski_slope_difficulty', ->(s) { difficulty[s.dig('difficulty')] })
          .>> t(:add_field, 'snow_resort', ->(s) { DataCycleCore::Thing.find_by(external_source_id: external_source_id, external_key: external_key_prefix + s.dig('snow_resort_id').to_s)&.id })
        end

        def self.to_ski_region
          t(:rename_keys, { 'id' => 'external_key' })
          .>> t(:add_field, 'name', ->(s) { s.dig('names', 'de') })
          .>> t(:add_field, 'external_key', ->(s) { external_key_prefix + s.dig('external_key').to_s })
          .>> t(:universal_classifications, ->(s) { opening_status[s.dig('status')] })
          .>> t(:universal_classifications, ->(s) { snow_type[s.dig('snowCondition', 'max')] })
          .>> t(:universal_classifications, ->(s) { snow_type[s.dig('snowCondition', 'min')] })
          .>> t(:universal_classifications, ->(s) { conditions[s.dig('snowCondition', 'max')] })
          .>> t(:universal_classifications, ->(s) { conditions[s.dig('snowCondition', 'max')] })
          .>> t(:universal_classifications, ->(s) { DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('Intermaps-iSKI - Schneezustand', s.dig('snowCondition', 'min')) })
          .>> t(:universal_classifications, ->(s) { DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('Intermaps-iSKI - Schneezustand', s.dig('snowCondition', 'max')) })
          .>> t(:add_field, 'date_last_snowfall', ->(s) { [s.dig('lastSnowfall', 'min')&.in_time_zone, s.dig('lstSnowfall', 'max')&.in_time_zone].compact.max })
          .>> t(:add_field, 'date_time_updated_at', ->(s) { s.dig('lastUpdate')&.in_time_zone })
          .>> t(:add_field, 'value', ->(s) { s.dig('lifts', 'open') })
          .>> t(:add_field, 'max_value', ->(s) { s.dig('lifts', 'total') })
          .>> t(:reject_keys, ['lifts'])
          .>> t(:nest, 'lifts', ['value', 'max_value'])
          .>> t(:add_field, 'same_as', ->(s) { s.dig('skimapLink', 'thumbnail') })
          .>> t(:add_field, 'value', ->(s) { s.dig('slopes', 'open') })
          .>> t(:add_field, 'max_value', ->(s) { s.dig('slopes', 'total') })
          .>> t(:nest, 'count_open_slopes', ['value', 'max_value'])
          .>> t(:add_field, 'value', ->(s) { s.dig('slopes', 'lengthOpen') })
          .>> t(:add_field, 'max_value', ->(s) { s.dig('slopes', 'lengthTotal') })
          .>> t(:add_field, 'snow_report', ->(s) { snow_report(s.dig('snowHeight')) })
          .>> t(:reject_keys, ['slopes'])
          .>> t(:nest, 'slopes', ['value', 'max_value'])
        end

        def self.snow_report(data)
          return [] if data.blank?
          report = []
          report += [{ 'name' => 'Tal', 'depth_of_snow' => data.dig('min')&.to_f }] if data.dig('min').present?
          report += [{ 'name' => 'Berg', 'depth_of_snow' => data.dig('max')&.to_f }] if data.dig('max').present?
          report
        end

        def self.external_key_prefix
          'IntermapsIski - Skigebiet - '
        end

        def self.lift_types
          @lift_types ||= {
            'funicular' => DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('odta:SkiLiftType', 'odta:Funicular'),
            'rack_railway' => DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('odta:SkiLiftType', 'odta:Funicular'),
            'magic_carpet' => DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('odta:SkiLiftType', 'odta:MagicCarpet'),
            'incline_elevator' => DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('odta:SkiLiftType', 'odta:MagicCarpet'),
            'funitel' => DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('odta:SkiLiftType', 'odta:CableCar'),
            'aerial_tramway' => DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('odta:SkiLiftType', 'odta:CableCar'),
            'aerial_tramway_two-storey' => DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('odta:SkiLiftType', 'odta:CableCar'),
            'monocable_gondola_lift' => DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('odta:SkiLiftType', 'odta:CableCar'),
            'bicable_gondola_lift' => DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('odta:SkiLiftType', 'odta:CableCar'),
            'tricable_gondola_lift' => DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('odta:SkiLiftType', 'odta:CableCar'),
            'pulsed_gondola' => DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('odta:SkiLiftType', 'odta:CableCar'),
            'cable_car' => DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('odta:SkiLiftType', 'odta:CableCar'),
            'rope_tow' => DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('odta:SkiLiftType', 'odta:RopeTow'),
            'button_lift' => DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('odta:SkiLiftType', 'odta:ButtonLift'),
            't-bar' => DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('odta:SkiLiftType', 'odta:TBarLift'),
            'chairlift' => DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('odta:SkiLiftType', 'odta:ChairLift'),
            'chairlift_gondola' => DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('odta:SkiLiftType', 'odta:ChairLift'),
            'single_chairlift' => DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('odta:SkiLiftType', 'odta:ChairLift'),
            'double_chairlift' => DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('odta:SkiLiftType', 'odta:ChairLift'),
            'triple_chairlift' => DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('odta:SkiLiftType', 'odta:ChairLift'),
            'quad_chairlift' => DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('odta:SkiLiftType', 'odta:ChairLift'),
            'sixpack_chairlift' => DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('odta:SkiLiftType', 'odta:ChairLift'),
            '8-seater_chairlift' => DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('odta:SkiLiftType', 'odta:ChairLift')
          }
        end

        def self.opening_status
          @opening_status ||= {
            'closed' => DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('odta:OpeningStatus', 'odta:Closed'),
            'temporarily_closed' => DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('odta:OpeningStatus', 'odta:Closed'),
            'open' => DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('odta:OpeningStatus', 'odta:Open'),
            'open_groomed' => DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('odta:OpeningStatus', 'odta:Open'),
            'open_ungroomed' => DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('odta:OpeningStatus', 'odta:Open'),
            'unknown' => DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('odta:OpeningStatus', 'odta:NoInformation'),
            'in_preperation' => DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('odta:OpeningStatus', 'odta:NoInformation'),
            'weekend' => DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('odta:OpeningStatus', 'odta:WeekendOnly')
          }
        end

        def self.slope_types
          @slope_types ||= {
            'skiroute' => DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('odta:SkiSlopeType', 'odta:SkiRoute'),
            'slope' => []
          }
        end

        def self.difficulty
          @difficulty ||= {
            'unknown' => [],
            'very_easy' => DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('odta:SkiSlopeDifficulty', 'odta:Easy'),
            'easy' => DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('odta:SkiSlopeDifficulty', 'odta:Easy'),
            'intermediate' => DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('odta:SkiSlopeDifficulty', 'odta:Medium'),
            'difficult' => DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('odta:SkiSlopeDifficulty', 'odta:Hard'),
            'very_difficult' => DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('odta:SkiSlopeDifficulty', 'odta:Hard')
          }
        end

        def self.conditions
          @conditions ||= {
            'corn_snow' => DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('odta:snowCondition', 'griffig'),
            'excellent' => DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('odta:snowCondition', 'griffig'),
            'grippy' => DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('odta:snowCondition', 'griffig'),
            'hard_pack' => DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('odta:snowCondition', 'hart'),
            'hard_powder' => DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('odta:snowCondition', 'hart'),
            'hard_slush' => DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('odta:snowCondition', 'hart'),
            'hard_wet' => DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('odta:snowCondition', 'hart'),
            'icy' => DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('odta:snowCondition', 'eisig'),
            'partly_icy' => DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('odta:snowCondition', 'eisig'),
            'snow-free' => DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('odta:snowCondition', 'stellenweise aper'),
            'wet_granular' => DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('odta:snowCondition', 'nass'),
            'wet_packed_snow' => DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('odta:snowCondition', 'nass'),
            'wet_snow' => DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('odta:snowCondition', 'nass')
          }
        end

        def self.snow_type
          @snow_type ||= {
            'hard_powder' => DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('odta:snowType', 'Pulver'),
            'hard_slush' => DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('odta:snowType', 'Sulz'),
            'hard_wet' => DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('odta:snowType', 'Nassschnee'),
            'new_powder' => DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('odta:snowType', 'Pulver'),
            'old_snow' => DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('odta:snowType', 'Altschnee'),
            'packed_powder' => DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('odta:snowType', 'Pulver'),
            'powder_granular' => DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('odta:snowType', 'Pulver'),
            'powder_slush' => DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('odta:snowType', 'Pulver'),
            'powder_wet' => DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('odta:snowType', 'Pulver'),
            'slush_powder' => DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('odta:snowType', 'Sulz'),
            'spring_conditions' => DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('odta:snowType', 'Altschnee'),
            'wet_granular' => DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('odta:snowType', 'Nassschnee'),
            'wet_packed_snow' => DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('odta:snowType', 'Nassschnee'),
            'wet_snow' => DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('odta:snowType', 'Nassschnee')
          }
        end

        def self.capacity
          @capacity ||= {
            'single_chairlift' => 1,
            'double_chairlift' => 2,
            'triple_chairlift' => 3,
            'quad_chairlift' => 4,
            'sixpack_chairlift' => 6,
            '8-seater_chairlift' => 8
          }
        end
      end
    end
  end
end
