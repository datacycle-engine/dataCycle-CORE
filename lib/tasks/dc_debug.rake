# frozen_string_literal: true

namespace :dc do
  namespace :debug do
    desc '[debug] show suspicious overlay data'
    task overlays: :environment do
      overlay_ids = DataCycleCore::ContentContent.where(relation_a: 'overlay').pluck(:content_b_id)
      bad_overlays = DataCycleCore::Thing.where(id: overlay_ids).map { |i|
        [i.id, i.available_locales] if i.available_locales.size != 1 && i.template_name != 'LodgingBusinessOverlay'
      }.compact
      puts 'Overlays without translation: '
      ap(bad_overlays.select { |i| i[1].blank? }.map { |i| i[0] })
      puts 'Overlays with multiple translations'
      ap(bad_overlays.select { |i| i[1].size > 1 }.map { |i| "#{i[0]} (#{i[1]})" })
    end

    desc '[debug] show suspicious embedded data'
    task embedded: :environment do
      data = []
      [
        'Ergänzende Information', 'SubEvent', 'AmenityFeature', 'Offer',
        'VirtualLocation', 'Skigebiet - Addon', 'Schneehöhe - Messpunkt'
      ].each do |template_name|
        data.push(DataCycleCore::Thing.where(template: false, template_name: template_name).map { |i|
          [i.id, template_name, i.available_locales] if i.available_locales.size != 1
        }.compact)
      end
      ap data.select(&:presence)
    end
  end
end
