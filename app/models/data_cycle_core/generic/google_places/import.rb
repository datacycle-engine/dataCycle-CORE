module DataCycleCore
  module Generic
    module GooglePlaces
      module Import
        def import_data(**options)
          @data_template = options.dig(:import, :data_template) || 'Örtlichkeit'
          @data_type = load_data_type_id(options.dig(:import, :data_type) || 'GooglePlaces')
          @poi_transformation = DataCycleCore::Generic::Transformations::Transformations.google_places_to_poi
          # @source_filter = options.dig(:import, :source_filter) || {}

          import_contents(@source_type, @target_type, method(:load_contents).to_proc, method(:process_content).to_proc, **options)
        end

        protected

        def load_contents(mongo_item, locale)
          mongo_item.where("dump.#{locale}": { '$exists' => true })
        end

        def process_content(raw_data, template, locale)
          I18n.with_locale(locale) do
            categories = raw_data.dig('types').map { |name|
              DataCycleCore::Classification.find_by(external_source_id: external_source.id, external_key: "GooglePlaces - Tags - #{name}")
            }.reject(&:nil?)

            periods = raw_data.dig('opening_hours', 'periods')
            opening_hours_specifications = nil
            if periods.present? && periods.size == 1 && periods.first.size == 1 && periods.first.dig('open', 'day') == 0 && periods.first.dig('open', 'time') == '0000'
              # --> always open
              opening_hours_specifications = (0..6).map do |item|
                {
                  opens: '00:00',
                  closes: '23:59',
                  day_of_week: [load_day_of_week_id(item)]
                }
              end
            elsif periods.present?
              opening_hours_specifications = periods.map do |item|
                opens = item.dig('open', 'time')
                closes = item.dig('close', 'time')
                day_of_week = item.dig('open', 'day')
                {
                  opens: "#{opens[0..1]}:#{opens[2..3]}",
                  closes: "#{closes[0..1]}:#{closes[2..3]}",
                  day_of_week: [load_day_of_week_id(day_of_week)]
                }.with_indifferent_access
              end
            end

            create_or_update_content(
              @target_type,
              load_template(@target_type, @data_template),
              extract_poi_data(raw_data).merge(
                data_type: [@data_type],
                google_tags: categories.map(&:id),
                opening_hours_specification: opening_hours_specifications
              ).with_indifferent_access
            )
          end
        end

        def extract_poi_data(raw_data)
          raw_data.nil? ? {} : @poi_transformation.call(raw_data)
        end

        def load_day_of_week_id(number)
          return nil if number.negative? || number > 6
          day_hash = {
            1 => 'Montag',
            2 => 'Dienstag',
            3 => 'Mittwoch',
            4 => 'Donnerstag',
            5 => 'Freitag',
            6 => 'Samstag',
            0 => 'Sonntag'
          }
          DataCycleCore::Classification.joins(classification_aliases: [classification_tree: [:classification_tree_label]])
            .where('classification_tree_labels.name = ?', 'Wochentage')
            .where('classification_aliases.name = ?', day_hash[number]).first!.id
        end

        def load_data_type_id(class_string)
          DataCycleCore::Classification.find_by(name: class_string, external_source_id: nil, external_key: nil)&.id
        end
      end
    end
  end
end
