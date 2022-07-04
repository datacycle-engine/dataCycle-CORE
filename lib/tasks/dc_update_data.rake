# frozen_string_literal: true

require 'rake_helpers/time_helper'

namespace :dc do
  namespace :update_data do
    desc 'update all computed attributes'
    task :computed_attributes, [:template_name, :webhooks, :computed_name, :dry_run] => [:environment] do |_, args|
      dry_run = args.fetch(:dry_run, false)
      webhooks = args.fetch(:webhooks, 'true').to_s
      template_name = args.fetch(:template_name, false).to_s
      computed_name = args.fetch(:computed_name, false).to_s
      computed_names = computed_name.present? && computed_name != 'false' ? computed_name.split(',') : false

      selected_things = DataCycleCore::Thing.where(template: true)
      selected_things = selected_things.where(template_name: template_name) if template_name.present? && template_name != 'false'

      selected_things.find_each do |template|
        next if template.computed_property_names.blank?
        next if computed_names.present? && computed_names.size.positive? && !(computed_names & template.computed_property_names).size.positive?

        items = DataCycleCore::Thing.where(template: false, template_name: template.template_name)
        translated_computed = (template.computed_property_names & template.translatable_property_names).present?
        keys_for_data_hash = template.property_names.difference(template.computed_property_names)
        keys_for_data_hash = keys_for_data_hash.intersection(template.property_definitions.slice(*computed_names).values.map { |d| d.dig('compute', 'parameters') }.flatten.uniq.compact) if computed_names.present?

        progressbar = ProgressBar.create(total: items.size, format: '%t |%w>%i| %a - %c/%C', title: template.template_name)

        items.find_each do |item|
          next if dry_run

          item.prevent_webhooks = true if webhooks == 'false'

          if translated_computed
            item.available_locales.each do |locale|
              I18n.with_locale(locale) do
                item.set_data_hash(data_hash: item.get_data_hash_partial(keys_for_data_hash), partial_update: true)
              end
            end
          else
            I18n.with_locale(item.first_available_locale) do
              item.set_data_hash(data_hash: item.get_data_hash_partial(keys_for_data_hash), partial_update: true)
            end
          end

          progressbar.increment
        rescue StandardError => e
          progressbar.increment

          puts "Error: #{e.message}\n#{e.backtrace.first(10).join("\n")}"
        end
      end

      if dry_run
        puts 'Dry run: no database changes made'
        exit(-1)
      end
    end

    desc 'add default values for all attributes'
    task :add_defaults, [:template_names, :webhooks, :imported] => [:environment] do |_, args|
      template_names = args.template_names&.split('|')&.map(&:squish)
      selected_things = DataCycleCore::Thing.where(template: true)
      selected_things = selected_things.where(template_name: template_names) if template_names.present?

      selected_things.find_each do |template|
        next if template.default_value_property_names.blank?

        items = DataCycleCore::Thing.where(template: false, template_name: template.template_name)
        items = items.where(external_source_id: nil) if args.imported&.to_s&.downcase == 'false'

        translated_properties = (template.default_value_property_names & template.translatable_property_names).present?
        keys_for_data_hash = template
          .property_definitions
          .slice(*template.default_value_property_names)
          .map { |k, d| [k, d.dig('default_value').is_a?(::Hash) ? d.dig('default_value', 'parameters') : nil] }
          .flatten
          .uniq
          .compact

        progressbar = ProgressBar.create(total: items.size, format: '%t |%w>%i| %a - %c/%C', title: template.template_name)

        items.find_each do |item|
          item.prevent_webhooks = args.webhooks&.to_s&.downcase == 'false'

          if translated_properties
            item.translated_locales.each do |locale|
              I18n.with_locale(locale) do
                data_hash = item.get_data_hash_partial(keys_for_data_hash)
                item.add_default_values(data_hash: data_hash, force: true)
                item.set_data_hash(data_hash: data_hash, partial_update: true)
              end
            end
          else
            I18n.with_locale(item.first_available_locale) do
              data_hash = item.get_data_hash_partial(keys_for_data_hash)
              item.add_default_values(data_hash: data_hash, force: true)
              item.set_data_hash(data_hash: data_hash, partial_update: true)
            end
          end

          progressbar.increment
        rescue StandardError => e
          progressbar.increment

          puts "Error: #{e.message}\n#{e.backtrace.first(10).join("\n")}"
        end
      end
    end
  end
end
