# frozen_string_literal: true

require 'v4/base'

module DataCycleCore
  module Api
    module V4
      module Filter
        class AdvancedNumericTest < DataCycleCore::V4::Base
          before(:all) do
            image_a = DataCycleCore::V4::DummyDataHelper.create_data('image')
            image_a.set_data_hash(data_hash: { width: 100, height: 100 })

            image_b = DataCycleCore::V4::DummyDataHelper.create_data('image')
            image_b.set_data_hash(data_hash: { width: 50, height: 50 })
          end

          test 'api/v4/things with filter[attribute][{attributeName}][in][min]' do
            post_params = {}
            post api_v4_things_path(post_params)
            assert_api_count_result(2)

            post_params = {
              filter: {
                attribute: {
                  width: {
                    in: {
                      min: '45'
                    }
                  }
                }
              }
            }
            post api_v4_things_path(post_params)
            assert_api_count_result(2)

            post_params = {
              filter: {
                attribute: {
                  width: {
                    in: {
                      min: '75'
                    }
                  }
                }
              }
            }
            post api_v4_things_path(post_params)
            assert_api_count_result(1)

            post_params = {
              filter: {
                attribute: {
                  width: {
                    in: {
                      min: '150'
                    }
                  }
                }
              }
            }
            post api_v4_things_path(post_params)
            assert_api_count_result(0)

            post_params = {
              filter: {
                attribute: {
                  height: {
                    in: {
                      min: '45'
                    }
                  }
                }
              }
            }
            post api_v4_things_path(post_params)
            assert_api_count_result(2)

            post_params = {
              filter: {
                attribute: {
                  height: {
                    in: {
                      min: '75'
                    }
                  }
                }
              }
            }
            post api_v4_things_path(post_params)
            assert_api_count_result(1)

            post_params = {
              filter: {
                attribute: {
                  height: {
                    in: {
                      min: '150'
                    }
                  }
                }
              }
            }
            post api_v4_things_path(post_params)
            assert_api_count_result(0)

            post_params = {
              filter: {
                attribute: {
                  width: {
                    in: {
                      min: '75'
                    }
                  },
                  height: {
                    in: {
                      min: '75'
                    }
                  }
                }
              }
            }
            post api_v4_things_path(post_params)
            assert_api_count_result(1)

            post_params = {
              filter: {
                attribute: {
                  width: {
                    in: {
                      max: '125'
                    }
                  },
                  height: {
                    in: {
                      max: '125'
                    }
                  }
                }
              }
            }
            post api_v4_things_path(post_params)
            assert_api_count_result(2)

            post_params = {
              filter: {
                attribute: {
                  width: {
                    in: {
                      max: '25'
                    }
                  },
                  height: {
                    in: {
                      max: '25'
                    }
                  }
                }
              }
            }
            post api_v4_things_path(post_params)
            assert_api_count_result(0)

            post_params = {
              filter: {
                attribute: {
                  width: {
                    in: {
                      min: '75',
                      max: '125'
                    }
                  }
                }
              }
            }
            post api_v4_things_path(post_params)
            assert_api_count_result(1)

            post_params = {
              filter: {
                attribute: {
                  width: {
                    in: {
                      min: '75',
                      max: '125'
                    }
                  },
                  height: {
                    in: {
                      min: '75',
                      max: '125'
                    }
                  }
                }
              }
            }
            post api_v4_things_path(post_params)
            assert_api_count_result(1)

            post_params = {
              filter: {
                attribute: {
                  width: {
                    in: {
                      min: '125',
                      max: '175'
                    }
                  },
                  height: {
                    in: {
                      min: '125',
                      max: '175'
                    }
                  }
                }
              }
            }
            post api_v4_things_path(post_params)
            assert_api_count_result(0)
          end

          test 'api/v4/things with filter[classifications][notIn]' do
            post_params = {}
            post api_v4_things_path(post_params)
            assert_api_count_result(2)

            post_params = {
              filter: {
                attribute: {
                  width: {
                    notIn: {
                      min: '45'
                    }
                  }
                }
              }
            }
            post api_v4_things_path(post_params)
            assert_api_count_result(0)

            post_params = {
              filter: {
                attribute: {
                  width: {
                    notIn: {
                      min: '75'
                    }
                  }
                }
              }
            }
            post api_v4_things_path(post_params)
            assert_api_count_result(1)

            post_params = {
              filter: {
                attribute: {
                  width: {
                    notIn: {
                      min: '150'
                    }
                  }
                }
              }
            }
            post api_v4_things_path(post_params)
            assert_api_count_result(2)

            post_params = {
              filter: {
                attribute: {
                  height: {
                    notIn: {
                      min: '45'
                    }
                  }
                }
              }
            }
            post api_v4_things_path(post_params)
            assert_api_count_result(0)

            post_params = {
              filter: {
                attribute: {
                  height: {
                    notIn: {
                      min: '75'
                    }
                  }
                }
              }
            }
            post api_v4_things_path(post_params)
            assert_api_count_result(1)

            post_params = {
              filter: {
                attribute: {
                  height: {
                    notIn: {
                      min: '150'
                    }
                  }
                }
              }
            }
            post api_v4_things_path(post_params)
            assert_api_count_result(2)

            post_params = {
              filter: {
                attribute: {
                  width: {
                    notIn: {
                      min: '75'
                    }
                  },
                  height: {
                    notIn: {
                      min: '75'
                    }
                  }
                }
              }
            }
            post api_v4_things_path(post_params)
            assert_api_count_result(1)

            post_params = {
              filter: {
                attribute: {
                  width: {
                    notIn: {
                      max: '125'
                    }
                  },
                  height: {
                    notIn: {
                      max: '125'
                    }
                  }
                }
              }
            }
            post api_v4_things_path(post_params)
            assert_api_count_result(0)

            post_params = {
              filter: {
                attribute: {
                  width: {
                    notIn: {
                      max: '25'
                    }
                  },
                  height: {
                    notIn: {
                      max: '25'
                    }
                  }
                }
              }
            }
            post api_v4_things_path(post_params)
            assert_api_count_result(2)

            post_params = {
              filter: {
                attribute: {
                  width: {
                    notIn: {
                      min: '75',
                      max: '125'
                    }
                  }
                }
              }
            }
            post api_v4_things_path(post_params)
            assert_api_count_result(1)

            post_params = {
              filter: {
                attribute: {
                  width: {
                    notIn: {
                      min: '75',
                      max: '125'
                    }
                  },
                  height: {
                    notIn: {
                      min: '75',
                      max: '125'
                    }
                  }
                }
              }
            }
            post api_v4_things_path(post_params)
            assert_api_count_result(1)

            post_params = {
              filter: {
                attribute: {
                  width: {
                    notIn: {
                      min: '125',
                      max: '175'
                    }
                  },
                  height: {
                    notIn: {
                      min: '125',
                      max: '175'
                    }
                  }
                }
              }
            }
            post api_v4_things_path(post_params)
            assert_api_count_result(2)
          end
        end
      end
    end
  end
end
