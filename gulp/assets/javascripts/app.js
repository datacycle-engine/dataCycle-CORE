// app.js - Data cylce Core
var $ = require('jquery');
var jqueryujs = require('jquery-ujs');
var foundation = require('foundation-sites');
var lazysizes = require('lazysizes');
var lazysizes_unveilhooks = require('lazysizes/plugins/unveilhooks/ls.unveilhooks.min.js');

var Vue = require('vue');
var AsyncComputed = require('vue-async-computed');
var CustomSelect = require('./vue/components/custom-select.vue');
var ObjectBrowser = require('./vue/components/object-browser.vue');
var EmbeddedObjects = require('./vue/components/embedded-objects.vue');

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
var content_object_init = require('./modules/initializers/content_object_init');
var slider_init = require('./modules/initializers/slider_init');
var copy_contents_init = require('./modules/initializers/copy_contents_init');
var map_init = require('./modules/initializers/map_init');
var watch_lists_init = require('./modules/initializers/watch_lists_init');
var classifications = require('./modules/initializers/classifications');
var lazyloading_init = require('./modules/initializers/lazyloading_init');
var datalist_init = require('./modules/initializers/datalist_init');

$(function () {
  // Initialize Masonry Grid
  masonry_init.initialize();

  // Initialize Foundation
  $(document).foundation();

  // initialize Vue + Custom Select + Object Browser
  if ($('.editor').length > 0) {
    Vue.use(AsyncComputed);

    var edit_form = new Vue({
      el: '.editor',
      components: {
        CustomSelect,
        ObjectBrowser,
        EmbeddedObjects
      }
    });
  }

  if ($('#newContent').length > 0) {
    var new_vue = new Vue({
      el: '#newContent form',
      components: {
        CustomSelect
      }
    });
  }

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

  // initialize Content Objects
  content_object_init.initialize();

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
