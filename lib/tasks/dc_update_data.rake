# frozen_string_literal: true

namespace :dc do
  namespace :update_data do
    desc 'Remove all data from external_source'
    task :computed_attributes, [:dry_run] => [:environment] do |_, args|
      dry_run = args.fetch(:dry_run, false)

      templates_w_computed = DataCycleCore::Thing.where(template: true).find_each.select { |template| template.computed_property_names.present? }.each do |template|
        items = DataCycleCore::Thing.where(template: false, template_name: template.template_name)
        ap "#{template.template_name}: #{items.size}"
      end
      ap templates_w_computed
      # byebug

      if dry_run
        puts 'Dry run: no database changes made'
        exit(-1)
      end
      exit(-1)
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
