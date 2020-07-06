# frozen_string_literal: true

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
        next if computed_names.size.positive? && !(computed_names & template.computed_property_names).size.positive?
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
              I18n.with_locale(locale) { item.set_data_hash(data_hash: item.get_data_hash) }
            end
          else
            I18n.with_locale(item.first_available_locale) { item.set_data_hash(data_hash: item.get_data_hash) }
          end
        end

        puts "#{''.ljust(41)} | #{(items_to_update || 0).to_s.rjust(8)} | #{(items_to_update || 0).to_s.rjust(8)} | #{format_time(Time.zone.now - temp, 5, 6, 's')} \r"
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

def format_time(time, n, m, unit)
  time.round(m).to_s.split('.').zip([->(x) { x.rjust(n) }, ->(x) { x.ljust(m, '0') }]).map { |x, f| f.call(x) }.join('.') + " #{unit}"
end
