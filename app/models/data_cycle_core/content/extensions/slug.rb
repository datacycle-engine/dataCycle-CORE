# frozen_string_literal: true

module DataCycleCore
  module Content
    module Extensions
      module Slug
        def remove_blank_slugs!(data_hash:)
          data_hash.keys.intersection(slug_property_names).each do |key|
            data_hash.delete(key) if data_hash[key].blank?
          end
        end

        def transform_slugs(data_hash:)
          data_hash.keys.intersection(slug_property_names).each do |key|
            # slugs cannot be blank
            next data_hash.delete(key) if data_hash[key].blank?

            data_hash[key] = slugify(data_hash[key])
          end
        end

        def slugify(value)
          return if value.blank?

          slugified_value = value.to_s.to_slug
          slug = slugified_value
          count = 0
          uniq_slug = nil

          while uniq_slug.nil?
            found = DataCycleCore::Thing::Translation.find_by(slug:)

            if found.nil? || (found.thing_id == id && found.locale == I18n.locale.to_s)
              uniq_slug = slug
              break
            end

            count += 1
            if count < 10
              "#{slugified_value}-#{count}"
            else
              slug = "#{slugified_value}-#{rand(36**8).to_s(36)}"
            end
          end

          uniq_slug
        end
      end
    end
  end
end
