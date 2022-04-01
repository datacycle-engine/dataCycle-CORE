# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Amtangee
      module Transformations
        def self.t(*args)
          DataCycleCore::Generic::Common::Functions[*args]
        end

        def self.to_thing
          t(:stringify_keys)
          .>> t(:add_field, 'id', ->(s) { s.dig('contact', 'vCloudID')&.downcase })
          .>> t(:add_field, 'name', ->(s) { s.dig('contact', 'name').squish })
          .>> t(:add_field, 'contact_info', ->(s) { parse_contact_info(s.dig('contact')) })
          .>> t(:add_field, 'address', ->(s) { parse_address(s.dig('contact')) })
          .>> t(:add_field, 'country_code', ->(s) { country_code(s.dig('contact')) })
          .>> t(:reject_keys, ['contact'])
          .>> t(:strip_all)
        end

        def self.parse_contact_info(s)
          external_id = s.dig('vCloudID').present? ? "VCLOUD:#{s.dig('vCloudID')}" : nil
          telephone_record = s
            .dig('phonenumbers')
            &.detect { |i| i.dig('type')&.squish == 'Firma' && i.dig('externalId')&.squish == external_id }
          telephone = [telephone_record&.dig('areacode')&.squish, telephone_record&.dig('number')&.squish].join(' ')
          email_record = s
            .dig('emailAddresses')
            &.detect { |i| i.dig('type')&.squish == 'Firma' && i.dig('externalId')&.squish == external_id }
          email = email_record&.dig('address')&.squish
          url = s.dig('website')&.squish
          url = 'https://' + url if url.present? && !url&.start_with?('http')
          {
            'telephone' => telephone.presence,
            'email' => email.presence,
            'url' => url.presence
          }.compact
        end

        def self.parse_address(s)
          external_id = s.dig('vCloudID').present? ? "VCLOUD:#{s.dig('vCloudID')}" : nil
          address = s
            .dig('addresses')
            &.detect { |i| i.dig('type')&.squish == 'Firma' && i.dig('externalId')&.squish == external_id }
          return if address.blank?
          {
            'street_address' => address.dig('street')&.squish&.presence,
            'postal_code' => address.dig('zip')&.squish&.presence,
            'address_locality' => address.dig('city')&.squish&.presence,
            'address_country' => address.dig('country')&.squish&.presence
          }.compact
        end

        def self.country_code(s)
          external_id = s.dig('vCloudID').present? ? "VCLOUD:#{s.dig('vCloudID')}" : nil
          address = s
            .dig('addresses')
            &.detect { |i| i.dig('type')&.squish == 'Firma' && i.dig('externalId')&.squish == external_id }
          return if address.blank?
          [
            DataCycleCore::ClassificationAlias
              .for_tree('Ländercodes')
              .find_by(description: address.dig('country'))
              &.primary_classification
              &.id
          ]
        end
      end
    end
  end
end
