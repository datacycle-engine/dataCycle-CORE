json.set! '@type', 'PostalAddress'
json.set! 'streetAddress', addressData.streetAddress unless addressData.streetAddress.blank?
json.set! 'postalCode', addressData.postalCode unless addressData.postalCode.blank?
json.set! 'addressLocality', addressData.addressLocality unless addressData.addressLocality.blank?
json.set! 'addressCountry', addressData.addressCountry unless addressData.addressCountry.blank?
