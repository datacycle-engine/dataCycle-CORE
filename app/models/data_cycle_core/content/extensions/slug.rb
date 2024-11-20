# frozen_string_literal: true

module DataCycleCore
  module Content
    module Extensions
      module Slug
        def transform_slugs(data_hash:)
          data_hash.keys.intersection(slug_property_names).each do |key|
            data_hash[key] = slugify(data_hash[key])
          end
        end

        def slugify(value)
          slugified = value.to_s.to_slug
          slug = slugified
          count = 0
          uniq_slug = nil

          while uniq_slug.nil?
            found = DataCycleCore::Thing::Translation.find_by(slug:)

            if found.blank? || (found.thing_id == id && found.locale == I18n.locale.to_s)
              uniq_slug = slug
              break
            end

            count += 1
            if count < 10
              slug = "#{slugified}-#{count}"
            else
              slug = "#{slugified}-#{rand(36**8).to_s(36)}"
            end
          end

          uniq_slug
        end
      end
    end
  end
end
