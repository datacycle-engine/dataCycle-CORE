# frozen_string_literal: true

module DataCycleCore
  module Content
    module Extensions
      module Slug
        def slugify(data_hash:)
          data_hash.keys.intersection(slug_property_names).each do |key|
            data_hash[key] = make_slug_uniq(data_hash[key]&.to_slug)
          end
        end

        def make_slug_uniq(base_slug)
          count = 0
          uniq_slug = nil
          slug = base_slug

          while uniq_slug.nil?
            found = DataCycleCore::Thing::Translation.find_by(slug:)

            if found.blank? || (found.thing_id == id && found.locale == I18n.locale.to_s)
              uniq_slug = slug
              break
            end

            count += 1
            if count < 10
              slug = "#{base_slug}-#{count}"
            else
              slug = "#{base_slug}-#{rand(36**8).to_s(36)}"
            end
          end

          uniq_slug
        end
      end
    end
  end
end
