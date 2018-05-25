// app.js - Data cylce Core
var $ = require('jquery');
var jquery_to_json = require('jquery-serializejson');
var jqueryujs = require('jquery-ujs');
var foundation = require('foundation-sites');
var lazysizes = require('lazysizes');
var lazysizes_unveilhooks = require('lazysizes/plugins/unveilhooks/ls.unveilhooks.min.js');

var initializers = [];
initializers.push(require('./modules/initializers/masonry_init'));
initializers.push(require('./modules/initializers/quill_init'));
initializers.push(require('./modules/initializers/filter_init'));
initializers.push(require('./modules/initializers/blur_init'));
initializers.push(require('./modules/initializers/detailheader_init'));
initializers.push(require('./modules/initializers/focus_init'));
initializers.push(require('./modules/initializers/flash_init'));
initializers.push(require('./modules/initializers/validation_init'));
initializers.push(require('./modules/initializers/counter_init'));
initializers.push(require('./modules/initializers/date_picker_init'));
initializers.push(require('./modules/initializers/slider_init'));
initializers.push(require('./modules/initializers/copy_contents_init'));
initializers.push(require('./modules/initializers/map_init'));
initializers.push(require('./modules/initializers/classifications'));
initializers.push(require('./modules/initializers/classification_select_init'));
initializers.push(require('./modules/initializers/lazyloading_init'));
initializers.push(require('./modules/initializers/datalist_init'));
initializers.push(require('./modules/initializers/object_browser_init'));
initializers.push(require('./modules/initializers/embedded_objects_init'));
initializers.push(require('./modules/initializers/iframe_init'));
initializers.push(require('./modules/initializers/assets_init'));
initializers.push(require('./modules/initializers/rails_confirmation_init'));
initializers.push(require('./modules/initializers/publication_init'));
initializers.push(require('./modules/initializers/stored_filters_init'));
initializers.push(require('./modules/initializers/dropdown_pane_init'));
initializers.push(require('./modules/initializers/file_upload_init'));


$(function () {

  initializers.forEach(element => {
    element.initialize();
  });

  // Initialize Foundation
  $(document).foundation();

  // HOME RANDOMIZED IMAGES AND GLASSHACK!
  if ($(".home-container").length) {
    $(".home-container").appendTo("body");
    setTimeout(function () {
      $('.home-container').addClass('show')
    }, 500);
    $('body').addClass('login-page');
  }

});
