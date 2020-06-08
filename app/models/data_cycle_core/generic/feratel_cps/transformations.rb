# frozen_string_literal: true

module DataCycleCore
  module Generic
    module FeratelCps
      module Transformations
        def self.t(*args)
          DataCycleCore::Generic::Common::Functions[*args]
        end

        def self.feratel_to_infrastructure(external_source_id)
          t(:stringify_keys)
          .>> t(:add_field, 'name', ->(s) { s.dig('NAME', 'text') })
          .>> t(:add_field, 'external_key', ->(s) { s.dig('ID', 'text') })
          .>> t(:load_category, 'feratel_cps_type', external_source_id, ->(s) { 'Feratel CPS - Typen - ' + s.dig('TYP', 'text') })
          .>> t(:load_category, 'feratel_cps_status', external_source_id, ->(s) { 'Feratel CPS - Stati - ' + s.dig('STATUSWERT', 'text') })
          .>> t(:reject_keys, ['GUID', 'ID', 'NAME', 'TYP', 'TYPKRZ', 'TYPNAME', 'STATUS', 'STATUSWERT'])
          .>> t(:strip_all)
        end

        def self.feratel_to_slope(external_source_id)
          t(:stringify_keys)
          .>> t(:add_field, 'name', ->(s) { s.dig('NAME', 'text') })
          .>> t(:add_field, 'external_key', ->(s) { s.dig('ID', 'text') })
          .>> t(:load_category, 'feratel_cps_type', external_source_id, ->(s) { 'Feratel CPS - Typen - ' + s.dig('TYP', 'text') })
          .>> t(:load_category, 'feratel_cps_status', external_source_id, ->(s) { 'Feratel CPS - Stati - ' + s.dig('STATUSWERT', 'text') })
          .>> t(:reject_keys, ['GUID', 'ID', 'NAME', 'TYP', 'TYPKRZ', 'TYPNAME', 'STATUS', 'STATUSWERT'])
          .>> t(:strip_all)
        end

        def self.feratel_to_lift(external_source_id)
          t(:stringify_keys)
          .>> t(:add_field, 'name', ->(s) { s.dig('NAME', 'text') })
          .>> t(:add_field, 'external_key', ->(s) { s.dig('ID', 'text') })
          .>> t(:load_category, 'feratel_cps_type', external_source_id, ->(s) { 'Feratel CPS - Typen - ' + s.dig('TYP', 'text') })
          .>> t(:load_category, 'feratel_cps_status', external_source_id, ->(s) { 'Feratel CPS - Stati - ' + s.dig('STATUSWERT', 'text') })
          .>> t(:reject_keys, ['GUID', 'ID', 'NAME', 'TYP', 'TYPKRZ', 'TYPNAME', 'STATUS', 'STATUSWERT'])
          .>> t(:strip_all)
        end
      end
    end
  end
end
