# frozen_string_literal: true

module DataCycleCore
  module Update
    class Base
      def update
        total_updates = query.count
        puts "UPDATE '#{@template.template_name}' templates - #{total_updates} items (#{Time.zone.now.strftime('%H:%M:%S.%3N')})"

        item_count = 0
        query.find_each do |content_item|
          data_hash_all = {}
          content_item.available_locales.each do |locale|
            I18n.with_locale(locale) do
              data_hash = read(content_item)
              data_hash_all = { locale => data_hash }
            end
          end
          modify_content(content_item)
          timestamp = Time.zone.now
          data_hash_all.each do |locale, data_hash|
            I18n.with_locale(locale) do
              error = write(content_item, data_hash, timestamp)
              if error[:error].blank?
                content_item.save
              else
                ap "ERROR: for #{table_name}(#{content_item.id}).with_locale(#{locale})"
                ap error
              end
            end
          end

          # progress bar
          if (item_count % 1000).zero?
            total_count = [total_updates, 1].max
            fraction = [100, (item_count * 100.0 / total_count).round(0)].min
            print "[#{'*' * fraction}#{' ' * (100 - fraction)}] #{fraction}% (#{Time.zone.now.strftime('%H:%M:%S.%3N')})\r"
          end
          item_count += 1
        end

        puts "[#{'*' * 100}] 100% (#{Time.zone.now.strftime('%H:%M:%S.%3N')})\r"
      end

      private

      def quoted(string)
        Arel::Nodes.build_quoted(string)
      end

      def json_path(field, path)
        Arel::Nodes::InfixOperation.new('#>>', field, path)
      end
    end
  end
end
