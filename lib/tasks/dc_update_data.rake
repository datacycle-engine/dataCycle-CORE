# frozen_string_literal: true

namespace :dc do
  namespace :update_data do
    desc 'update all computed attributes'
    task :computed_attributes, [:template_name, :webhooks, :dry_run] => [:environment] do |_, args|
      dry_run = args.fetch(:dry_run, false)
      webhooks = args.fetch(:webhooks, 'true')
      template_name = args.fetch(:template_name, false)

      if template_name.present?
        selected_things = DataCycleCore::Thing.where(template: true, template_name: template_name)
      else
        selected_things = DataCycleCore::Thing.where(template: true)
      end

      selected_things.find_each.select { |template| template.computed_property_names.present? }.each do |template|
        items = DataCycleCore::Thing.where(template: false, template_name: template.template_name)
        items_to_update = items.size
        translated_computed = (template.computed_property_names & template.translatable_property_names).present?

        puts "Computed attributes found in:  #{template.template_name}"

        progressbar = ProgressBar.create(total: items_to_update, format: '%t |%w>%i| %a - %c/%C', title: template.template_name)
        items.find_each do |item|
          next progressbar.increment if dry_run

          item.prevent_webhooks = true if webhooks == 'false'

          if translated_computed
            item.available_locales.each do |locale|
              I18n.with_locale(locale) { item.set_data_hash(data_hash: item.get_data_hash) }
            end
          else
            I18n.with_locale(item.first_available_locale) { item.set_data_hash(data_hash: item.get_data_hash) }
          end

          progressbar.increment
        end
      end

      if dry_run
        puts 'Dry run: no database changes made'
        exit(-1)
      end
    end
  end
end

def zsh?
  ENV['SHELL']&.split('/')&.last == 'zsh'
end

def error(msg)
  puts msg
  exit(-1)
end
