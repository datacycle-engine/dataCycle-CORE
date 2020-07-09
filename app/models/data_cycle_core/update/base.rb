# frozen_string_literal: true

module DataCycleCore
  module Update
    class Base
      def update
        progressbar = ProgressBar.create(total: query.size, format: '%t |%w>%i| %a - %c/%C', title: @template.template_name)

        query.includes(classification_aliases: [:classification_alias_path, :classification_tree_label]).find_each do |content_item|
          data_hash_all = {}
          content_item.available_locales.each do |locale|
            I18n.with_locale(locale) do
              data_hash = read(content_item)
              data_hash_all = { locale => data_hash }
            end
          end
          modify_content(content_item)
          data_hash_all.each do |locale, data_hash|
            I18n.with_locale(locale) do
              error = write(content_item, data_hash, Time.zone.now)
              if error[:error].present?
                ap "ERROR: for #{table_name}(#{content_item.id}).with_locale(#{locale})"
                ap error
              end
            end
          end
          progressbar.increment
        end
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
