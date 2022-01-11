# frozen_string_literal: true

module DataCycleCore
  module Export
    module OutdoorActive
      module Transformations
        def self.to_xml(external_system, contents, deleted_content_ids = [])
          @source = external_system.credentials(:export).dig('xml', 'source')
          @owner =  external_system.credentials(:export).dig('xml', 'owner')

          builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
            xml.pois('xmlns' => 'http://www.outdooractive.com/api/schema/alp.interface', 'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance', 'xsi:schemaLocation' => 'http://www.outdooractive.com/api/schema/alp.interface alp.interface.pois.xsd') do
              xml.source @source
              contents.each do |content|
                xml.poi('id' => content.id,
                        'workflow' => Functions.outdoor_active_system_status(content, external_system),
                        'lastmodified' => content.updated_at.strftime('%Y-%m-%d %H:%M:%S')) do
                  outdoor_active_system_source_keys(content, xml, external_system)
                  # xml.author 'DataCycle'
                  outdoor_active_system_categories(content, xml, external_system)
                  xml.point outdoor_active_point(content.location) if content.respond_to?(:location) && content.location.present?
                  outdoor_active_contact(content, xml)
                  outdoor_active_descriptons(content, xml)
                  parent_data = {
                    'source' => Functions.outdoor_active_system_source_keys(content, external_system).first&.name,
                    'name' => content.name
                  }
                  outdoor_active_images(content, xml, parent_data)
                end
              end

              deleted_content_ids.each do |id|
                xml.poi('id' => id, 'workflow' => 'deleted')
              end
            end
          end
          builder.to_xml
        end

        def self.outdoor_active_point(location)
          "#{location.y} #{location.x}" if location.present?
        end

        def self.outdoor_active_contact(content, xml)
          return if content.blank?
          xml.contact do
            if content.address.present?
              xml.address do
                xml.street content.address.try(:street_address) if content.address.try(:street_address).present?
                xml.number content.address.try(:number) if content.address.try(:number).present?
                xml.municipality content.address.try(:address_locality) if content.address.try(:address_locality).present?
                xml.postalcode content.address.try(:postal_code) if content.address.try(:postal_code).present?
              end
            end
            xml.tel content.contact_info.try(:telephone) if content.contact_info.try(:telephone).present?
            xml.fax content.contact_info.try(:telephone) if content.contact_info.try(:telephone).present?
            xml.email content.contact_info.try(:email) if content.contact_info.try(:email).present?
            xml.url content.contact_info.try(:url) if content.contact_info.try(:url).present?
          end
        end

        def self.outdoor_active_descriptons(content, xml)
          # TODO: missing Outdoor Active atttributes:
          # parking
          # getting_there
          # businessHours
          # fee

          xml.descriptions do
            content.translations.each do |translation|
              I18n.with_locale(translation.locale) do
                xml.description('lang' => translation.locale) do
                  xml.title content.name
                  xml.abstract ActionView::Base.full_sanitizer.sanitize(content.description) if content.description.present?
                  xml.text_ ActionView::Base.full_sanitizer.sanitize(content.text) if content.text.present?
                end
              end
            end
          end
          xml
        end

        def self.outdoor_active_images(content, xml, parent_data)
          # TODO: missing:
          # point

          image_attributes = [:primary_image, :image, :logo]

          xml.images do
            image_attributes.each do |image_attribute|
              next if content.try(image_attribute).blank?
              content.try(image_attribute).each do |image|
                xml.image('id' => image.id, 'src' => image.content_url) do
                  xml.source image.copyright_holder.first&.name || parent_data.dig('source')
                  xml.author image.try(:author)&.first&.name || parent_data.dig('name')
                  image.translations.each do |translation|
                    I18n.with_locale(translation.locale) do
                      xml.description('lang' => translation.locale) do
                        xml.title image.name
                      end
                    end
                  end
                end
              end
            end
          end
        end

        def self.outdoor_active_system_categories(content, xml, external_system)
          categories = Functions.outdoor_active_system_categories(content, external_system)
          return if categories.blank?
          if categories.count == 1
            xml.category categories.first.external_key.split(':').last
          else
            xml.categories do
              categories.each do |category|
                xml.category category.external_key.split(':').last
              end
            end
          end
        end

        def self.outdoor_active_system_source_keys(content, xml, external_system)
          categories = Functions.outdoor_active_system_source_keys(content, external_system)
          if categories.blank?
            xml.owner @owner if @owner.present?
          else
            xml.owner categories.first.external_key.split(':').last
          end
        end
      end
    end
  end
end
