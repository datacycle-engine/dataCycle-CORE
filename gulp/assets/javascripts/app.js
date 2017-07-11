// app.js - Data cylce Core
var $ = require('jquery');
var jqueryujs = require('jquery-ujs');
var foundation = require('foundation-sites');

var Vue = require('vue');
var AsyncComputed = require('vue-async-computed');
var CustomSelect = require('./vue/components/custom-select.vue');
var ObjectBrowser = require('./vue/components/object-browser.vue');
var EmbeddedObjects = require('./vue/components/embedded-objects.vue');

var masonry_init = require('./modules/initializers/masonry_init');
var quill_init = require('./modules/initializers/quill_init');
var filter_init = require('./modules/initializers/filter_init');
var blur_init = require('./modules/initializers/blur_init');
var focus_init = require('./modules/initializers/focus_init');
var flash_init = require('./modules/initializers/flash_init');
var validation_init = require('./modules/initializers/validation_init');
var counter_init = require('./modules/initializers/counter_init');
var datepicker_init = require('./modules/initializers/date_picker_init');
var content_object_init = require('./modules/initializers/content_object_init');
var slider_init = require('./modules/initializers/slider_init');


// Initialize Masonry Grid
masonry_init.initialize();

$(function () {
  // Initialize Foundation
  $(document).foundation();

  // initialize Vue + Custom Select + Object Browser
  if ($('#edit-form').length > 0) {
    Vue.use(AsyncComputed);

    var edit_form = new Vue({
      el: '#edit-form',
      components: {
        CustomSelect,
        ObjectBrowser,
        EmbeddedObjects
      }
    });
  }

  // Initialize Filter Events
  filter_init.initialize();

  // Initialize Filter Events
  blur_init.initialize();

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
});