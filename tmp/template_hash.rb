template_hash = {
  data: {
    metadata: {
      template_name: "test-template",
      type: "root",
      data_cycle: {
        validation: {
        }
      }
    },
    headline: "this is a test-template",
    description: "this is a test for the import function of templates",
    position: 0,
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



template_hash1 = {
  data: {
    metadata: {
      template_name: "test-template",
      type: "root"
    },
    headline: "this is a test-template",
    description: "this is a test for the import function of templates",
    position: 1,
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
  }
}


simple_hash = {
    metadata: {
      template_name: "test-template",
      type: "root"
    },
    headline: "this is a test-template",
    description: "this is a test for the import function of templates",
    position: 1,
    content: {
      url: "http://www.google.de",
      text: "Sprechen Sie Deutsch?"
    },
    properties: {
      property1: "test1",
      property2: "test2"
    }
}

json-schema
