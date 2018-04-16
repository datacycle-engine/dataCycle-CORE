require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'

describe DataCycleCore::Generic::Feratel::ImportPlaces do
  subject do
    Object.new.tap { |o| o.extend(DataCycleCore::Generic::Feratel::ImportPlaces) }
  end

  describe 'data extraction for accommodations' do
    let(:raw_data) do
      JSON[
        <<-EOT
        {
            "Id" : "79a6d015-e646-4393-8595-0010c02554e1",
            "Details": {
                "Name" : {
                    "text" : "All inclusive Familienhotel Burgstallerhof"
                },
                "Names" : {
                    "Translation" : {
                        "Language" : "de",
                        "text" : "All inclusive Familienhotel Burgstallerhof"
                    }
                },
                "Town" : {
                    "VTCode" : "TXFELDAS",
                    "text" : "b6237704-5d57-4885-8945-cca2b9af39e5"
                },
                "District" : {
                    "text" : "a635d23f-f807-40a7-a54a-70b02151a633"
                },
                "Code" : {
                    "text" : "F0010"
                },
                "Type" : {
                    "text" : "Accommodation"
                },
                "Priority" : {
                    "text" : "88"
                },
                "Rooms" : {
                    "text" : "35"
                },
                "Beds" : {
                    "text" : "70"
                },
                "Position" : {
                    "Latitude" : "46.7766325823042",
                    "Longitude" : "13.7460246786503"
                },
                "Stars" : {
                    "Id" : "3115EE0F-D6A0-4B3F-987A-F4EB421C2422"
                },
                "Categories" : {
                    "Item" : {
                        "Id" : "AB4F2086-F06D-4DAC-8B99-09EDA5577C67"
                    }
                },
                "MarketingGroups" : {
                    "Item" : [
                        {
                            "Id" : "A3C9E5F6-1030-4530-8966-05A6B00A1223"
                        },
                        {
                            "Id" : "547EFCA5-AA11-4706-9D67-2724C80BF37E"
                        },
                        {
                            "Id" : "687CA04A-CBD0-430D-9212-798B4E2BAF76"
                        },
                        {
                            "Id" : "79E3C7C7-EAE8-4A59-A2B6-3000155E054A"
                        }
                    ]
                },
                "Active" : {
                    "text" : "true"
                },
                "CreditCards" : {
                    "CreditCard" : [
                        {
                            "Name" : "MasterCard"
                        },
                        {
                            "Name" : "VISA"
                        }
                    ]
                },
                "GridSquare" : {
                    "text" : "PQ"
                },
                "PlanNumber" : {
                    "text" : "18"
                },
                "DBCode" : {
                    "text" : "KTN"
                },
                "Bookable" : {
                    "text" : "true"
                },
                "BankAccounts" : {
                    "Bank" : {
                        "Id" : "e661a654-a985-4515-aca7-fc6ea2de624e",
                        "IBAN" : "AT14 39 457 00000 437 749",
                        "Account" : "437 749"
                    }
                },
                "CurrencyCode" : {
                    "text" : "EUR"
                },
                "DataOwner" : {
                    "text" : "BKK"
                }
            },
            "Descriptions": {
              "Description" : [
                {
                  "Id" : "9988f158-a2de-4b44-9744-3246a1d63173",
                  "Type" : "ServiceProviderDescription",
                  "Language" : "de",
                  "Systems" : "L T I C",
                  "ShowFrom" : "304",
                  "ShowTo" : "417",
                  "ChangeDate" : "2017-05-29T15:09:00",
                  "text" : "... Beschreibungstext 1 ..."
                },
                {
                  "Id" : "e89cf860-1241-42a1-888c-42a8e8aec037",
                  "Type" : "ServiceProviderDescription",
                  "Language" : "de",
                  "Systems" : "L T I C",
                  "ShowFrom" : "101",
                  "ShowTo" : "1231",
                  "ChangeDate" : "2017-05-29T15:07:00",
                  "text" : "... Beschreibungstext 2 ..."
                },
                {
                  "Id" : "dbbe0ca9-ea34-4286-bf14-4cc9ed22a8ef",
                  "Type" : "ServiceProviderConditions",
                  "Language" : "de",
                  "Systems" : "L T I C",
                  "ShowFrom" : "101",
                  "ShowTo" : "1231",
                  "ChangeDate" : "2017-05-29T15:09:00",
                  "text" : "... Beschreibungstext 3 ..."
                },
                {
                  "Id" : "83ba9a8f-4ee7-41b3-a241-51a4ca188336",
                  "Type" : "ServiceProviderDescription",
                  "Language" : "de",
                  "Systems" : "L T I C",
                  "ShowFrom" : "504",
                  "ShowTo" : "1016",
                  "ChangeDate" : "2017-05-29T15:08:00",
                  "text" : "... Beschreibungstext 4 ..."
                },
                {
                  "Id" : "d8b76b85-a434-4809-875e-b4227b1a63a2",
                  "Type" : "ServiceProviderArrivalVoucher",
                  "Language" : "de",
                  "Systems" : "L T I C",
                  "ShowFrom" : "308",
                  "ShowTo" : "322",
                  "ChangeDate" : "2017-05-29T15:14:00",
                  "text" : "... Beschreibungstext 5 ..."
                }
              ]
            },
            "Addresses": {
              "Address" : [
                {
                    "Type" : "Object",
                    "ChangeDate" : "2017-10-19T10:17:00",
                    "Id" : "10e0e144-2464-495e-99d3-3c6abaaf9ff9",
                    "Company" : {
                        "text" : "All inclusive Familienhotel Burgstallerhof"
                    },
                    "Title" : {
                        "text" : "Herrn"
                    },
                    "FirstName" : {
                        "text" : "Ernst"
                    },
                    "LastName" : {
                        "text" : "Burgstaller"
                    },
                    "AddressLine1" : {
                        "text" : "Dorfstraße 10"
                    },
                    "Country" : {
                        "text" : "AT"
                    },
                    "ZipCode" : {
                        "text" : "9544"
                    },
                    "Town" : {
                        "text" : "Feld am See"
                    },
                    "Email" : {
                        "text" : "hotel@burgstallerhof.at"
                    },
                    "Fax" : {
                        "text" : "+43 4246 3952"
                    },
                    "URL" : {
                        "text" : "http://www.burgstallerhof.at"
                    },
                    "Phone" : {
                        "text" : "+43 4246 2297"
                    },
                    "Mobile" : {
                        "text" : "+43 664 5047462"
                    }
                },
                {
                    "Type" : "Owner",
                    "ChangeDate" : "2017-10-19T10:17:00",
                    "Id" : "10e0e144-2464-495e-99d3-3c6abaaf9ff9",
                    "Company" : {
                        "text" : "All inclusive Familienhotel Burgstallerhof"
                    },
                    "Title" : {
                        "text" : "Herrn"
                    },
                    "FirstName" : {
                        "text" : "Ernst"
                    },
                    "LastName" : {
                        "text" : "Burgstaller"
                    },
                    "AddressLine1" : {
                        "text" : "Dorfstraße 10"
                    },
                    "Country" : {
                        "text" : "AT"
                    },
                    "ZipCode" : {
                        "text" : "9544"
                    },
                    "Town" : {
                        "text" : "Feld am See"
                    },
                    "Email" : {
                        "text" : "hotel@burgstallerhof.at"
                    },
                    "Fax" : {
                        "text" : "+43 4246 3952"
                    },
                    "URL" : {
                        "text" : "http://www.burgstallerhof.at"
                    },
                    "Phone" : {
                        "text" : "+43 4246 2297"
                    },
                    "Mobile" : {
                        "text" : "+43 664 5047462"
                    }
                }
              ]
            }
        }
        EOT
      ]
    end

    it 'extracts external key' do
      subject.extract_place_data(raw_data)['external_key'].must_equal '79a6d015-e646-4393-8595-0010c02554e1'
    end

    it 'extracts name' do
      subject.extract_place_data(raw_data)['name'].must_equal 'All inclusive Familienhotel Burgstallerhof'
    end

    it 'extracts latitude' do
      subject.extract_place_data(raw_data)['latitude'].must_equal 46.7766325823042
    end

    it 'extracts longitude' do
      subject.extract_place_data(raw_data)['longitude'].must_equal 13.7460246786503
    end

    it 'extracts location' do
      subject.extract_place_data(raw_data)['location'].must_equal(
        RGeo::Geographic.spherical_factory(srid: 4326).point(13.7460246786503, 46.7766325823042)
      )
    end

    it 'extracts short description' do
      subject.extract_place_data(raw_data)['description'].must_equal '... Beschreibungstext 1 ...'
    end

    it 'extracts address' do
      subject.extract_place_data(raw_data)['address']['street_address'].must_equal 'Dorfstraße 10'
      subject.extract_place_data(raw_data)['address']['address_locality'].must_equal 'Feld am See'
      subject.extract_place_data(raw_data)['address']['postal_code'].must_equal '9544'
      subject.extract_place_data(raw_data)['contact_info']['telephone'].must_equal '+43 4246 2297'
      subject.extract_place_data(raw_data)['contact_info']['fax_number'].must_equal '+43 4246 3952'
      subject.extract_place_data(raw_data)['contact_info']['email'].must_equal 'hotel@burgstallerhof.at'
      subject.extract_place_data(raw_data)['contact_info']['url'].must_equal 'http://www.burgstallerhof.at'
    end
  end
end
