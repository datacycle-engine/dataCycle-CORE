require 'test_helper'

module DataCycleCore
  module MasterData
    module Validators

      class ObjectTest < ActiveSupport::TestCase

        # tests for validate (keys in data-hash are keys in template)
        test "init object validator" do
          error_hash = { error: [], warning: []}
          template_hash = {
            "greeting" => {
              "label" => "test_string",
              "type" => "string",
              "storage_type" => "string",
              "storage_location" => "content"
            },
            "anzahl" => {
              "label" => "test_number",
              "type" => "number",
              "storage_type" => "number",
              "storage_location" => "content"
            }
          }
          data_hash = {
              "greeting" => "Hello World!",
              "anzahl" => 5
          }
          validator = DataCycleCore::MasterData::Validators::Object.new(data_hash,template_hash)
          assert_equal( error_hash, validator.error)
        end

        test "error wrong type in object validator" do
          template_hash = {
            "greeting" => {
              "label" => "test_string",
              "type" => "wrong type",
              "storage_type" => "string",
              "storage_location" => "content"
            }
          }
          data_hash = {
              "greeting" => "Hello World!"
          }
          validator = DataCycleCore::MasterData::Validators::Object.new(data_hash,template_hash)
          assert_equal(1, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
        end

        test "no error/ignore additional data given" do
          template_hash = {
            "greeting" => {
              "label" => "test_string",
              "type" => "string",
              "storage_type" => "string",
              "storage_location" => "content"
            },
            "anzahl" => {
              "label" => "test_number",
              "type" => "number",
              "storage_type" => "number",
              "storage_location" => "content"
            }
          }
          data_hash = {
              "greeting" => "Hello World!",
              "anzahl" => 5,
              "xxx" => "xxx"
          }
          validator = DataCycleCore::MasterData::Validators::Object.new(data_hash,template_hash)
          assert_equal(0, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
        end

        test "warning data missing" do
          template_hash = {
            "greeting" => {
              "label" => "test_string",
              "type" => "string",
              "storage_type" => "string",
              "storage_location" => "content"
            },
            "anzahl" => {
              "label" => "test_number",
              "type" => "number",
              "storage_type" => "number",
              "storage_location" => "content"
            }
          }
          data_hash = {
              "greeting" => "Hello World!"
          }
          validator = DataCycleCore::MasterData::Validators::Object.new(data_hash,template_hash)
          assert_equal(0, validator.error[:error].size)
          assert_equal(1, validator.error[:warning].size)
        end

        test "error object definition missing" do
          template_hash = {
            "greeting" => {
              "label" => "test_string",
              "type" => "string",
              "storage_type" => "string",
              "storage_location" => "content"
            },
            "anzahl" => {
              "label" => "test_number",
              "type" => "object",
              "storage_location" => "content"
            }
          }
          data_hash = {
              "greeting" => "Hello World!",
              "anzahl" => 5
          }
          validator = DataCycleCore::MasterData::Validators::Object.new(data_hash,template_hash)
          assert_equal(1, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
        end

        test "error collecting" do
          template_hash = {
            "greeting" => {
              "label" => "test_string",
              "type" => "string",
              "storage_type" => "string",
              "storage_location" => "content"
            },
            "anzahl" => {
              "label" => "test_number",
              "type" => "object",
              "storage_location" => "content",
              "properties" => {
                "test1" => {
                  "label" => "test1",
                  "type" => "string",
                  "storage_type" => "string",
                  "storage_location" => "content"
                },
                "test2" => {
                  "label" => "test2",
                  "type" => "string",
                  "storage_type" => "string",
                  "storage_location" => "content"
                }
              }

            }
          }
          data_hash = {
              "greeting" => 0,
              "anzahl" => {
                "test1" => 1,
                "test2" => 2
              }
          }
          validator = DataCycleCore::MasterData::Validators::Object.new(data_hash,template_hash)
          assert_equal(3, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
          data_hash = {
              "greeting" => 0,
              "anzahl" => {
                "test1" => 1
              }
          }
          validator = DataCycleCore::MasterData::Validators::Object.new(data_hash,template_hash)
          assert_equal(2, validator.error[:error].size)
          assert_equal(1, validator.error[:warning].size)
        end

        test "object validator daterange with proper template, and varying test-data" do
          template_hash = {
            "validityPeriod" => {
              "label" =>  "Gültigkeitszeitraum",
              "type" => "object",
              "storage_location" => "metadata",
              "validations" => {
                "daterange" => {
                  "from" => "validFrom",
                  "to" => "validUntil"
                }
              },
              "properties" => {
                "validFrom" => {
                  "label" => "Gültigkeit",
                  "type" => "string",
                  "storage_type" => "string",
                  "storage_location" => "metadata",
                  "validations" => {
                    "format" => "date_time"
                  }
                },
                "validUntil" => {
                  "label" => "bis",
                  "type" => "string",
                  "storage_type" => "string",
                  "storage_location" => "metadata",
                  "validations" => {
                    "format" => "date_time"
                  }
                }
              }
            }
          }

          data_hash = {
            "validityPeriod" => {
              "validFrom" => "2016-01-01",
              "validUntil" => "2017-01-01"
            }
          }
          validator = DataCycleCore::MasterData::Validators::Object.new(data_hash,template_hash)
          assert_equal(0, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)

          data_hash = {
            "validityPeriod" => {
              "validFrom" => "2017-01-01",
              "validUntil" => "2016-01-01"
            }
          }
          validator = DataCycleCore::MasterData::Validators::Object.new(data_hash,template_hash)
          assert_equal(1, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)

          data_hash = {
            "validityPeriod" => {
              "validFrom" => "a",
              "validUntil" => "b"
            }
          }
          validator = DataCycleCore::MasterData::Validators::Object.new(data_hash,template_hash)
          assert_equal(3, validator.error[:error].size)
          assert_equal(2, validator.error[:warning].size)

          data_hash = {
            "validityPeriod" => {
              "validFrom" => "a",
              "validUntil" => "2017-01-01"
            }
          }
          validator = DataCycleCore::MasterData::Validators::Object.new(data_hash,template_hash)
          assert_equal(2, validator.error[:error].size)
          assert_equal(1, validator.error[:warning].size)

          data_hash = {
            "validityPeriod" => {
              "validFrom" => "",
              "validUntil" => "2017-01-01"
            }
          }
          validator = DataCycleCore::MasterData::Validators::Object.new(data_hash,template_hash)
          assert_equal(0, validator.error[:error].size)
          assert_equal(1, validator.error[:warning].size)

          data_hash = {
            "validityPeriod" => {
              "validFrom" => "",
              "validUntil" => ""
            }
          }
          validator = DataCycleCore::MasterData::Validators::Object.new(data_hash,template_hash)
          assert_equal(0, validator.error[:error].size)
          assert_equal(2, validator.error[:warning].size)
        end

        test "object validator daterange with faulty templates, and fixed test-data" do
          template_hash = {
            "validityPeriod" => {
              "label" =>  "Gültigkeitszeitraum",
              "type" => "object",
              "storage_location" => "metadata",
              "validations" => {
                "daterange" => {
                  "from" => "from",
                  "to" => "validUntil"
                }
              },
              "properties" => {
                "validFrom" => {
                  "label" => "Gültigkeit",
                  "type" => "string",
                  "storage_type" => "string",
                  "storage_location" => "metadata",
                  "validations" => {
                    "format" => "date_time"
                  }
                },
                "validUntil" => {
                  "label" => "bis",
                  "type" => "string",
                  "storage_type" => "string",
                  "storage_location" => "metadata",
                  "validations" => {
                    "format" => "date_time"
                  }
                }
              }
            }
          }

          data_hash = {
            "validityPeriod" => {
              "validFrom" => "2016-01-01",
              "validUntil" => "2017-01-01"
            }
          }
          validator = DataCycleCore::MasterData::Validators::Object.new(data_hash,template_hash)
          assert_equal(1, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)

          template_hash = {
            "validityPeriod" => {
              "label" =>  "Gültigkeitszeitraum",
              "type" => "object",
              "storage_location" => "metadata",
              "validations" => {
                "daterange" => {
                  "from" => "validFrom",
                  "to" => "to"
                }
              },
              "properties" => {
                "validFrom" => {
                  "label" => "Gültigkeit",
                  "type" => "string",
                  "storage_type" => "string",
                  "storage_location" => "metadata",
                  "validations" => {
                    "format" => "date_time"
                  }
                },
                "validUntil" => {
                  "label" => "bis",
                  "type" => "string",
                  "storage_type" => "string",
                  "storage_location" => "metadata",
                  "validations" => {
                    "format" => "date_time"
                  }
                }
              }
            }
          }
          validator = DataCycleCore::MasterData::Validators::Object.new(data_hash,template_hash)
          assert_equal(1, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)

          template_hash = {
            "validityPeriod" => {
              "label" =>  "Gültigkeitszeitraum",
              "type" => "object",
              "storage_location" => "metadata",
              "validations" => {
                "daterange" => {
                  "from" => "validFrom"
                }
              },
              "properties" => {
                "validFrom" => {
                  "label" => "Gültigkeit",
                  "type" => "string",
                  "storage_type" => "string",
                  "storage_location" => "metadata",
                  "validations" => {
                    "format" => "date_time"
                  }
                },
                "validUntil" => {
                  "label" => "bis",
                  "type" => "string",
                  "storage_type" => "string",
                  "storage_location" => "metadata",
                  "validations" => {
                    "format" => "date_time"
                  }
                }
              }
            }
          }
          validator = DataCycleCore::MasterData::Validators::Object.new(data_hash,template_hash)
          assert_equal(1, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)

          template_hash = {
            "validityPeriod" => {
              "label" =>  "Gültigkeitszeitraum",
              "type" => "object",
              "storage_location" => "metadata",
              "validations" => {
                "daterange" => {
                  "to" => "validUntil"
                }
              },
              "properties" => {
                "validFrom" => {
                  "label" => "Gültigkeit",
                  "type" => "string",
                  "storage_type" => "string",
                  "storage_location" => "metadata",
                  "validations" => {
                    "format" => "date_time"
                  }
                },
                "validUntil" => {
                  "label" => "bis",
                  "type" => "string",
                  "storage_type" => "string",
                  "storage_location" => "metadata",
                  "validations" => {
                    "format" => "date_time"
                  }
                }
              }
            }
          }
          validator = DataCycleCore::MasterData::Validators::Object.new(data_hash,template_hash)
          assert_equal(1, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)

          template_hash = {
            "validityPeriod" => {
              "label" =>  "Gültigkeitszeitraum",
              "type" => "object",
              "storage_location" => "metadata",
              "validations" => {
                "daterange" => {}
              },
              "properties" => {
                "validFrom" => {
                  "label" => "Gültigkeit",
                  "type" => "string",
                  "storage_type" => "string",
                  "storage_location" => "metadata",
                  "validations" => {
                    "format" => "date_time"
                  }
                },
                "validUntil" => {
                  "label" => "bis",
                  "type" => "string",
                  "storage_type" => "string",
                  "storage_location" => "metadata",
                  "validations" => {
                    "format" => "date_time"
                  }
                }
              }
            }
          }
          validator = DataCycleCore::MasterData::Validators::Object.new(data_hash,template_hash)
          assert_equal(1, validator.error[:error].size)
          assert_equal(0, validator.error[:warning].size)
        end

        test "object validator daterange with template validations not implemented" do
          template_hash = {
            "validityPeriod" => {
              "label" =>  "Gültigkeitszeitraum",
              "type" => "object",
              "storage_location" => "metadata",
              "validations" => {
                "daterange" => {
                  "from" => "validFrom",
                  "to" => "validUntil"
                },
                "integerrange" => {
                  "from" => "validFrom",
                  "to" => "validUntil"
                },
                "format" => "data_time"
              },
              "properties" => {
                "validFrom" => {
                  "label" => "Gültigkeit",
                  "type" => "string",
                  "storage_type" => "string",
                  "storage_location" => "metadata",
                  "validations" => {
                    "format" => "date_time"
                  }
                },
                "validUntil" => {
                  "label" => "bis",
                  "type" => "string",
                  "storage_type" => "string",
                  "storage_location" => "metadata",
                  "validations" => {
                    "format" => "date_time"
                  }
                }
              }
            }
          }

          data_hash = {
            "validityPeriod" => {
              "validFrom" => "2016-01-01",
              "validUntil" => "2017-01-01"
            }
          }
          validator = DataCycleCore::MasterData::Validators::Object.new(data_hash,template_hash)
          assert_equal(0, validator.error[:error].size)
          assert_equal(2, validator.error[:warning].size)
        end

      end
    end
  end
end
