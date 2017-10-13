json.set! '@type', 'PostalAddress'
json.set! 'streetAddress', addressData.street_address unless addressData.street_address.blank?
json.set! 'postalCode', addressData.postal_code unless addressData.postal_code.blank?
json.set! 'addressLocality', addressData.address_locality unless addressData.address_locality.blank?
json.set! 'addressCountry', addressData.address_country unless addressData.address_country.blank?
