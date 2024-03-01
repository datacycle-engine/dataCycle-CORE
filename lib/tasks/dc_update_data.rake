# frozen_string_literal: true

require 'rake_helpers/time_helper'
require 'rake_helpers/parallel_helper'

namespace :dc do
  namespace :update_data do
    desc 'update all computed attributes'
    task :computed_attributes, [:template_name, :webhooks, :computed_name, :dry_run] => [:environment] do |_, args|
      dry_run = args.fetch(:dry_run, false)
      webhooks = args.fetch(:webhooks, 'true').to_s
      template_names = args.fetch(:template_name, false).to_s.then { |t| t.present? && t != 'false' ? t.split('|') : false }
      computed_names = args.fetch(:computed_name, false).to_s.then { |c| c.present? && c != 'false' ? c.split('|') : false }
      selected_things = DataCycleCore::ThingTemplate.all
      selected_things = selected_things.where(template_name: template_names) if template_names.present?

      puts "ATTRIBUTES TO UPDATE: #{computed_names.present? ? computed_names.join(', ') : 'all'}"

      selected_things.find_each do |thing_template|
        template = DataCycleCore::Thing.new(thing_template:)
        next if template.computed_property_names.blank?
        next if computed_names.present? && computed_names.any? && (computed_names & template.computed_property_names).none?

        items = DataCycleCore::Thing.where(template_name: template.template_name)
        computed_keys = computed_names.presence || template.computed_property_names
        translated_computed = computed_keys.intersect?(template.translatable_property_names)
        progressbar = ProgressBar.create(total: items.size, format: '%t |%w>%i| %a - %c/%C', title: template.template_name)

        update_proc = lambda { |content, keys|
          data_hash = {}
          content.add_computed_values(data_hash:, keys:, force: true)
          content.set_data_hash(data_hash:, update_computed: false)
        }

        items.find_in_batches.with_index do |batch, index|
          pid = Process.fork do
            progressbar.progress = index * 1000

            batch.each do |item|
              next progressbar.increment if dry_run

              item.prevent_webhooks = true if webhooks == 'false'

              if translated_computed
                item.available_locales.each do |locale|
                  keys = locale == item.first_available_locale ? computed_keys : computed_keys.intersection(template.translatable_property_names)
                  I18n.with_locale(locale) { update_proc.call(item, keys) }
                end
              else
                I18n.with_locale(item.first_available_locale) { update_proc.call(item, computed_keys) }
              end
            rescue StandardError => e
              puts "Error: #{e.message}\n#{e.backtrace.first(10).join("\n")}"
            ensure
              progressbar.increment
            end
          end

          Process.waitpid(pid)
        end
      end

      if dry_run
        puts 'Dry run: no database changes made'
        exit(-1)
      end
    end

    desc 'add default values for all attributes'
    task :add_defaults, [:template_names, :webhooks, :default_value_names, :imported, :thread_pool_size] => [:environment] do |_, args|
      template_names = args.template_names&.split('|')&.map(&:squish)
      selected_things = DataCycleCore::ThingTemplate.all
      selected_things = selected_things.where(template_name: template_names) if template_names.present?
      default_value_names = args.fetch(:default_value_names, false).to_s.then { |c| c.present? && c != 'false' ? c.split('|') : false }.freeze
      thread_pool_size = [args.thread_pool_size&.to_i, ActiveRecord::Base.connection_pool.size - 1].compact.min
      queue = DataCycleCore::WorkerPool.new(thread_pool_size)

      puts "ATTRIBUTES TO UPDATE: #{default_value_names.present? ? default_value_names.join(', ') : 'all'}, THREADS: #{thread_pool_size}"

      selected_things.find_each do |thing_template|
        template = DataCycleCore::Thing.new(thing_template:)
        next if template.default_value_property_names.blank?
        next if default_value_names.present? && default_value_names.any? && (default_value_names & template.default_value_property_names).none?

        items = DataCycleCore::Thing.where(template_name: template.template_name)
        items = items.where(external_source_id: nil) if args.imported&.to_s&.downcase == 'false'

        translated_properties = template.default_value_property_names.intersect?(template.translatable_property_names)
        progressbar = ProgressBar.create(total: items.size, format: '%t |%w>%i| %a - %c/%C', title: template.template_name)

        update_proc = lambda { |item|
          data_hash = {}
          item.add_default_values(data_hash:, force: true, keys: default_value_names)
          item.set_data_hash(data_hash:)
        }

        items.find_in_batches.with_index do |batch, index|
          pid = Process.fork do
            progressbar.progress = index * 1000

            batch.each do |item|
              queue.append do
                item.prevent_webhooks = args.webhooks&.to_s&.downcase == 'false'

                if translated_properties
                  item.translated_locales.each do |locale|
                    I18n.with_locale(locale) { update_proc.call(item) }
                  end
                else
                  I18n.with_locale(item.first_available_locale) { update_proc.call(item) }
                end
              rescue StandardError => e
                puts "Error: #{e.message}\n#{e.backtrace.first(10).join("\n")}"
              ensure
                progressbar.increment
              end
            end

            queue.wait!
          end

          Process.waitpid(pid)
        end
      end
    end
  end
end
