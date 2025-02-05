# frozen_string_literal: true

class RebuildAssetUrls < ActiveRecord::Migration[7.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    to_recompute = []
    DataCycleCore::ContentProperties.all.each do |content_property| # rubocop:disable Rails/FindEach
      next unless content_property.property_definition&.key?('compute')
      next unless Array.wrap(content_property.property_definition.dig('compute', 'parameters')).include?('asset')
      next unless content_property.property_name.include?('_url')

      to_recompute << content_property.property_name
    end

    return if to_recompute.empty?

    DataCycleCore::RunTaskJob.perform_later('dc:update_data:computed_attributes', [nil, false, to_recompute.uniq.join('|')])
  end

  def down
  end
end
