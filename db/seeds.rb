# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).


# idempodent

# insert dummy admin
if DataCycleCore::User.where(name: "Test Admin", email: "test@pixelpoint.at").count == 0
  DataCycleCore::User.create!(
    name: "Test Admin",
    email: "test@pixelpoint.at",
    admin: true,
    password:"password"
  )
end

# insert a template_tree
if DataCycleCore::CreativeWork.where(headline: "this is a test-template", template: true).count == 0
  template_hash = {
    data: {
      metadata: {
        template_name: "test-template",
        type: "root",
        data_cycle: {
          validation: {
            "type": "object",
            "properties": {
              "data": {
                "type": "object",
                "properties": {
                  "headline": { "type": "string" },
                  "position": { "type": "integer", "minimum": 0, "maximum": 32767 },
                  "metadata": {
                    "type": "object",
                    "properties": {
                      "external_key": { "type": "string" }
                    }
                  },
                  "translations": {
                    "type": "object",
                    "properties": {
                      "de": {
                        "type": "object",
                        "properties": {
                          "content": { "type": "object",
                            "properties": {
                              "url": { "type": "string", "format": "uri" }
                            }
                          },
                          "properties": {
                            "type": "object",
                            "properties": {
                              "gallery": {
                                "type": "string",
                                "pattern": "^([A-Za-z0-9+/]{4})*([A-Za-z0-9+/]{4}|[A-Za-z0-9+/]{3}=|[A-Za-z0-9+/]{2}==)$"
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      },
      headline: "this is a test-template",
      description: "this is a test for the import function of templates",
      position: 0,
      template: true,
      translations: {
        de: {
          content: {
            url: "http://www.google.de",
            text: "Sprechen Sie Deutsch?"
          },
          properties: {
            property1: "test1",
            property2: "test2"
          }
        },
        en: {
          content: {
            url: "http://www.google.com",
            text: "Do you speak English?"
          }
        },
        it: {
          content: {
            url: "http://www.google.it",
            text: "Parlare italiano?"
          }
        }
      }
    },
    nodes: [
      {
        data: {
          metadata: {
            template_name: "test-template",
            type: "leaf1"
          },
          headline: "this is a test-template/leaf1",
          description: "this is a test for the import function of templates",
          position: 0,
          template: true,
          translations: {
            de: {
              content: {
                url: "http://www.google.de",
                text: "Sprechen Sie Deutsch?"
              },
              properties: {
                property1: "test1,leaf1",
                property2: "test2,leaf1"
              }
            },
            en: {
              content: {
                url: "http://www.google.com",
                text: "Do you speak English?"
              }
            },
            it: {
              content: {
                url: "http://www.google.it",
                text: "Parlare italiano?"
              }
            }
          }
        }
      },
      {
        data: {
          metadata: {
            template_name: "test-template",
            type: "leaf2"
          },
          headline: "this is a test-template/leaf2",
          description: "this is a test for the import function of templates",
          position: 1,
          template: true,
          translations: {
            de: {
              content: {
                url: "http://www.google.de",
                text: "Sprechen Sie Deutsch?/leaf2"
              },
              properties: {
                property1: "test1/leaf2",
                property2: "test2/leaf2"
              }
            },
            en: {
              content: {
                url: "http://www.google.com",
                text: "Do you speak English?/leaf2"
              }
            },
            it: {
              content: {
                url: "http://www.google.it",
                text: "Parlare italiano?/leaf2"
              }
            }
          }
        },
        nodes: [
          {
            data: {
              metadata: {
                template_name: "test-template",
                type: "leaf2/leaf1"
              },
              headline: "this is a test-template/leaf2/leaf1",
              description: "this is a test for the import function of templates",
              position: 0,
              template: true,
              translations: {
                de: {
                  content: {
                    url: "http://www.google.de",
                    text: "Sprechen Sie Deutsch?leaf2/leaf1"
                  },
                  properties: {
                    property1: "test1,leaf2/leaf1",
                    property2: "test2,leaf2/leaf1"
                  }
                },
                en: {
                  content: {
                    url: "http://www.google.com",
                    text: "Do you speak English?leaf2/leaf1"
                  }
                },
                it: {
                  content: {
                    url: "http://www.google.it",
                    text: "Parlare italiano?leaf2/leaf1"
                  }
                }
              }
            }
          },
          {
            data: {
              metadata: {
                template_name: "test-template",
                type: "leaf2/leaf2"
              },
              headline: "this is a test-template/leaf2/leaf2",
              description: "this is a test for the import function of templates",
              position: 1,
              template: true,
              translations: {
                de: {
                  content: {
                    url: "http://www.google.de",
                    text: "Sprechen Sie Deutsch?/leaf2/leaf2"
                  },
                  properties: {
                    property1: "test1/leaf2/leaf2",
                    property2: "test2/leaf2/leaf2"
                  }
                },
                en: {
                  content: {
                    url: "http://www.google.com",
                    text: "Do you speak English?/leaf2/leaf2"
                  }
                },
                it: {
                  content: {
                    url: "http://www.google.it",
                    text: "Parlare italiano?/leaf2/leaf2"
                  }
                }
              }
            }
          }
        ]
      }
    ]
  }
  DataCycleCore::CreativeWork.save_template(template_hash)
end
