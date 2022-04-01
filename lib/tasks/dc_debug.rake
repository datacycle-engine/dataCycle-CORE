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

    desc '[destructive][debug] delete suspicious overlay data'
    task clean_overlays: :environment do
      overlay_ids = DataCycleCore::ContentContent.where(relation_a: 'overlay').pluck(:content_b_id)
      bad_overlays = DataCycleCore::Thing.where(id: overlay_ids).map { |i|
        [i.id, i.available_locales] if i.available_locales.size != 1 && i.template_name != 'LodgingBusinessOverlay'
      }.compact
      overlays = bad_overlays.select { |i| i[1].blank? }.map { |i| i[0] }
      items = DataCycleCore::Thing.where(id: overlays)
      DataCycleCore::ProgressBarService.for_shell(items.count, title: "remove Overlays without translations (#{items.count}):") do |pb|
        items.find_each do |item|
          pb.inc
          item.destroy_content(save_history: false)
        end
      end
    end

    desc '[debug] show content with more than one overlay'
    task overlay_survey: :environment do
      DataCycleCore::ContentContent.select(:content_a_id).where(relation_a: 'overlay')
        .group(:content_a_id).having('count(relation_a) > ?', 1)
        .map(&:content_a_id)
        .map do |i|
          puts "#{i}; #{DataCycleCore::Thing.find(i).template_name}; #{DataCycleCore::Thing.find(i).load_embedded_objects('overlay', nil, false).map { |o| o.translations.pluck(:locale) }.inject(:+)}"
        end
    end

    desc '[debug] migrate translated overlays'
    task overlay_migration: :environment do
      items = DataCycleCore::ContentContent.select(:content_a_id).where(relation_a: 'overlay')
        .group(:content_a_id).having('count(relation_a) > ?', 1)
        .map(&:content_a_id)
        .map do |i|
        DataCycleCore::Thing.find(i)
      end
      items.each do |item|
        # item = items.second
        de_overlay = nil
        en_overlay = nil
        de_overlay_data_hash = nil
        en_overlay_data_hash = nil

        I18n.with_locale(:de) do
          de_overlay = item.overlay.detect { |a| a.available_locales.include?(:de) }
          de_overlay_data_hash = de_overlay.get_data_hash
        end
        raise nil.inspect if de_overlay.nil?

        I18n.with_locale(:en) do
          en_overlay = item.overlay&.detect { |a| a.available_locales.include?(:en) }
          en_overlay_data_hash = en_overlay.get_data_hash

          next if en_overlay.blank?
          en_overlay_data_hash['id'] = de_overlay_data_hash['id']
        end

        de_overlay.embedded_property_names.each do |embedded_property|
          if de_overlay_data_hash.dig(embedded_property).size == 1 && en_overlay_data_hash.dig(embedded_property).size == 1
            en_overlay_data_hash[embedded_property][0]['id'] = de_overlay_data_hash[embedded_property][0]['id']
          elsif de_overlay_data_hash.dig(embedded_property).empty? && en_overlay_data_hash.dig(embedded_property).empty?

          elsif de_overlay_data_hash.dig(embedded_property).size == 1 && en_overlay_data_hash.dig(embedded_property).empty?

          elsif (de_overlay_data_hash.dig(embedded_property).size == en_overlay_data_hash.dig(embedded_property).size) && embedded_property == 'opening_hours_specification'
            en_overlay_data_hash[embedded_property] = de_overlay_data_hash[embedded_property]
          else
            puts "#{de_overlay_data_hash.dig(embedded_property).size} | #{en_overlay_data_hash.dig(embedded_property).size} | #{item.id}\n"
          end
        end

        I18n.with_locale(:en) do
          item.set_data_hash(data_hash: { overlay: [en_overlay_data_hash] }, prevent_history: true)
        end

        I18n.with_locale(:de) do
          item.set_data_hash(data_hash: { overlay: [de_overlay_data_hash] }, prevent_history: true)
        end
      end
    end
  end
end
