# frozen_string_literal: true

require 'rake_helpers/time_helper'

namespace :dc do
  namespace :update_data do
    desc 'update all computed attributes'
    task :computed_attributes, [:template_name, :webhooks, :computed_name, :dry_run] => [:environment] do |_, args|
      dry_run = args.fetch(:dry_run, false)
      webhooks = args.fetch(:webhooks, 'true')
      template_name = args.fetch(:template_name, false)
      computed_name = args.fetch(:computed_name, false)
      computed_names = computed_name.present? && computed_name != 'false' ? computed_name.split(',') : false

      if template_name.present? && template_name != 'false'
        selected_things = DataCycleCore::Thing.where(template: true, template_name: template_name)
      else
        selected_things = DataCycleCore::Thing.where(template: true)
      end

      selected_things.find_each.select { |template| template.computed_property_names.present? }.each do |template|
        next if computed_names.present? && computed_names.size.positive? && !(computed_names & template.computed_property_names).size.positive?
        items = DataCycleCore::Thing.where(template: false, template_name: template.template_name)
        items_to_update = items.size
        translated_computed = (template.computed_property_names & template.translatable_property_names).present?

        puts "#{template.template_name}\r"
        puts "#{('# ' + items_to_update.to_s).ljust(41)} | #updated | of total | process time/s \r"

        temp = Time.zone.now

        items.find_each do |item|
          next if dry_run

          item.prevent_webhooks = true if webhooks == 'false'

          if translated_computed
            item.available_locales.each do |locale|
              I18n.with_locale(locale) { item.set_data_hash(data_hash: item.get_data_hash.except(*template.computed_property_names)) }
            end
          else
            I18n.with_locale(item.first_available_locale) { item.set_data_hash(data_hash: item.get_data_hash.except(*template.computed_property_names)) }
          end
        end

        puts "#{''.ljust(41)} | #{(items_to_update || 0).to_s.rjust(8)} | #{(items_to_update || 0).to_s.rjust(8)} | #{TimeHelper.format_time(Time.zone.now - temp, 5, 6, 's')} \r"
      end

      if dry_run
        puts 'Dry run: no database changes made'
        exit(-1)
      end
    end

    desc 'add default values for all attributes'
    task :add_defaults, [:template_names, :webhooks, :imported] => [:environment] do |_, args|
      template_names = args.template_names&.split('|')&.map(&:squish)

      contents = DataCycleCore::Thing.where(template: false).where.not(content_type: 'embedded')
      contents = contents.where(template_name: template_names) if template_names.present?
      contents = contents.where(external_source_id: nil) if args.imported&.to_s&.downcase == 'false'

      progressbar = ProgressBar.create(total: contents.size, format: '%t |%w>%i| %a - %c/%C', title: 'Progress')

      contents.find_each do |content|
        next if content.properties_with_default_values.blank?

        content.translated_locales.each do |locale|
          I18n.with_locale(locale) do
            data_hash = {}
            content.add_default_values(data_hash: data_hash, force: true)
            content.prevent_webhooks = args.webhooks&.to_s&.downcase == 'false'
            begin
              content.set_data_hash(data_hash: data_hash, partial_update: true)
            rescue StandardError => e
              puts e.message
            end
          end
        end
        progressbar.increment
      end
    end
  end
end
