// app.js - Data cylce Core
var $ = require('jquery');
var jquery_to_json = require('jquery-serializejson');
var jqueryujs = require('jquery-ujs');
var foundation = require('foundation-sites');
var lazysizes = require('lazysizes');
var lazysizes_unveilhooks = require('lazysizes/plugins/unveilhooks/ls.unveilhooks.min.js');

var masonry_init = require('./modules/initializers/masonry_init');
var quill_init = require('./modules/initializers/quill_init');
var filter_init = require('./modules/initializers/filter_init');
var blur_init = require('./modules/initializers/blur_init');
var detailheader_init = require('./modules/initializers/detailheader_init');
var focus_init = require('./modules/initializers/focus_init');
var flash_init = require('./modules/initializers/flash_init');
var validation_init = require('./modules/initializers/validation_init');
var counter_init = require('./modules/initializers/counter_init');
var datepicker_init = require('./modules/initializers/date_picker_init');
var slider_init = require('./modules/initializers/slider_init');
var copy_contents_init = require('./modules/initializers/copy_contents_init');
var map_init = require('./modules/initializers/map_init');
var watch_lists_init = require('./modules/initializers/watch_lists_init');
var classifications = require('./modules/initializers/classifications');
var classification_select_init = require('./modules/initializers/classification_select_init');
var lazyloading_init = require('./modules/initializers/lazyloading_init');
var datalist_init = require('./modules/initializers/datalist_init');
var object_browser_init = require('./modules/initializers/object_browser_init');
var embedded_objects_init = require('./modules/initializers/embedded_objects_init');
var iframe_init = require('./modules/initializers/iframe_init');
var assets_init = require('./modules/initializers/assets_init');


$(function () {
  // Initialize Masonry Grid
  masonry_init.initialize();

  // Initialize Foundation
  $(document).foundation();

  // Initialize Filter Events
  filter_init.initialize();

  // Initialize Filter Events
  blur_init.initialize();

  // Initialize Detailheader Events
  detailheader_init.initialize();

  // Initialize Focus Events and Classes
  focus_init.initialize();

  // Initialize Flash Slideup
  flash_init.initialize();

  // Initialize Form Validation
  validation_init.initialize();

  // initialize Quill Editor
  quill_init.initialize();

  // initialize Date Picker
  datepicker_init.initialize();

  // initialize Word Counter
  counter_init.initialize();

  // initialize Foundation Sliders
  slider_init.initialize();

  // initialize Copy_Contents
  copy_contents_init.initialize();

  // initialize Watchlists
  watch_lists_init.initialize();

  // initialize Watchlists
  lazyloading_init.initialize();

  // initialize Datalists
  datalist_init.initialize();

  // initialize ObjectBrowsers
  object_browser_init.initialize();

  // initialize Embedded Objects
  embedded_objects_init.initialize();

  // initialize Embedded Objects
  assets_init.initialize();

  // initialize Classigication Selector
  classification_select_init.initialize();

  // initialize Iframe Events
  iframe_init.initialize();

  if ($('#classification-administration').length) {
    classifications.initialize();
  }

  // HOME RANDOMIZED IMAGES AND GLASSHACK!
  if ($(".home-container").length) {
    $(".home-container").appendTo("body");
    setTimeout(function () {
      $('.home-container').addClass('show')
    }, 500);
    $('body').addClass('login-page');
  }

});
