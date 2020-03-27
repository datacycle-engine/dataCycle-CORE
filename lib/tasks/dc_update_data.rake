# frozen_string_literal: true

namespace :dc do
  namespace :update_data do
    desc 'update all computed attributes'
    task :computed_attributes, [:template_name, :dry_run] => [:environment] do |_, args|
      dry_run = args.fetch(:dry_run, false)
      template_name = args.fetch(:template_name, false)

      if template_name.present?
        selected_things = DataCycleCore::Thing.where(template: true, template_name: template_name)
      else
        selected_things = DataCycleCore::Thing.where(template: true)
      end

      selected_things.find_each.select { |template| template.computed_property_names.present? }.each do |template|
        items = DataCycleCore::Thing.where(template: false, template_name: template.template_name)
        items_to_update = items.size

        puts "Computed attributes found in:  #{template.template_name}"
        puts "Updating #{items_to_update.to_s.rjust(6)} #{' ' * 88} 0% (#{Time.zone.now.strftime('%H:%M:%S.%3N')})\n"
        index = 0
        items.each do |item|
          progress_bar(items_to_update, index)
          index += 1
          next if dry_run
          item.set_data_hash(data_hash: item.get_data_hash)
        end
        progress_bar(items_to_update, items_to_update)
      end

      if dry_run
        puts 'Dry run: no database changes made'
        exit(-1)
      end
    end
  end
end

def progress_bar(total_items, index, interval = nil)
  if index >= total_items
    print "[#{'*' * 100}] 100% (#{Time.zone.now.strftime('%H:%M:%S.%3N')})\n"
    return
  end
  interval ||= [total_items / 100.0, 1.0].max.round(0)
  return unless (index % interval).zero?
  fraction = (((index * 1.0) / total_items) * 100.0).round(0)
  fraction = 100 if fraction > 100
  print "[#{'*' * fraction}#{' ' * (100 - fraction)}] #{fraction.to_s.rjust(3)}% (#{Time.zone.now.strftime('%H:%M:%S.%3N')})\r"
end

def zsh?
  ENV['SHELL']&.split('/')&.last == 'zsh'
end

def error(msg)
  puts msg
  exit(-1)
end
