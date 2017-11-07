module DataCycleCore
  module Update
    class Base

      def update()
        puts "BEGIN Update (#{Time.zone.now.strftime("%H:%M:%S.%3N")})"

        item_count = 0
        query().each do |content_item|
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
              unless error[:error].blank?
                ap "ERROR: for #{table_name}(#{content_item.id}).with_locale(#{locale})"
                ap error
              else
                content_item.save
              end
            end
          end

          # remove history


          item_count +=1
          puts "#{item_count.to_s.rjust(7)} items processed. (#{Time.zone.now.strftime("%H:%M:%S.%3N")})" if (item_count % 100) == 0
        end

        puts "END (#{Tine.zone.now.strftime("%H:%M:%S.%3N")})"

      end

    private
      def quoted(string)
        Arel::Nodes.build_quoted(string)
      end

      def json_path(field, path)
        Arel::Nodes::InfixOperation.new("#>>", field, path)
      end
    end
  end
end
