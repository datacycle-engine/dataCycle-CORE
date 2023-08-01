# frozen_string_literal: true

namespace :dc do
  namespace :export do
    desc 'export POI'
    task poi: :environment do
      require 'csv'
      tsv = CSV.open(Rails.root.join('log', 'POI.tsv'), 'wb')
      tsv << [['#ID', 'EVENTPLACE', 'LATITUDE', 'LONGITUDE', 'STREET', 'COUNTRY', 'CITY', 'ZIP', 'COMMENT'].join("\t")]
      tsv << [['#ID', 'EVENTPLACE', 'LATITUDE', 'LONGITUDE', 'STREET', 'COUNTRY', 'CITY', 'ZIP', 'COMMENT'].join("\t")]
      DataCycleCore::Thing.where(template_name: 'POI').each do |item|
        tsv << [[item.id, item.name, item.latitude.presence, item.longitude.presence, item.address.street_address.presence, item.address.address_country.presence, item.address.address_locality.presence, item.address.postal_code.presence, item.id].join("\t")]
      end
      tsv.close
    end
  end
end
