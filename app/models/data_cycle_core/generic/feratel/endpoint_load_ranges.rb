# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Feratel
      module EndpointLoadRanges
        def load_range_ids_new
          raise ArgumentError, 'missing read_type for loading location ranges' if @read_type.nil?
          range_types = { 'Country' => 'RG', 'Region' => 'RG', 'District' => 'DI', 'Town' => 'TO' }
          range_parameters = DataCycleCore::Generic::Collection2.with(@read_type) do |mongo|
            mongo.where({ 'dump.de.ParentID' => /#{@primary_range_id}/i })
              .to_a.map { |r| [range_types[r.dump['de']['_Type']], r.dump['de']['Id']] }
              .presence
          end
          (range_parameters.presence || []) + [[@primary_range_code, @primary_range_id]]
        end

        def load_range_ids(range_code = 'RG')
          range_ids = load_location_range_ids(
            @options.dig(:options, :location_range_codes)
          )

          if range_ids.include?(range_code)
            range_ids[range_code]
          elsif range_code == @primary_range_code
            [@primary_range_id]
          else
            []
          end
        end

        def load_location_range_ids(range_codes)
          raise ArgumentError, 'missing read_type for loading location ranges' if @read_type.nil?
          range_codes ||= []

          DataCycleCore::Generic::Collection2.with(@read_type) do |mongo|
            range_codes.map(&:to_s).uniq.map { |code|
              {
                code => mongo.where({ 'dump.de._Type' => range_type(code) }).map { |r| r.dump['de']['Id'] } # , 'dump.de.ParentID' => { '$ne' => '00000000-0000-0000-0000-000000000000' }
              }
            }.reduce({}, &:merge)
          end
        end

        def range_type(range_code)
          case range_code
          when 'RG' then 'Region'
          when 'DI' then 'District'
          when 'TO' then 'Town'
          end
        end
      end
    end
  end
end
