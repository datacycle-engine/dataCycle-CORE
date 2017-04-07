var $ = require('jquery');
var jqueryujs = require('jquery-ujs');
var foundation = require('foundation-sites');
var turbolinks = require('turbolinks');
var masonry = require('masonry-layout');

var test = require('./modules/test.js');

/*
Init
*/
turbolinks = new turbolinks.start();

$(function(){
  $(document).foundation();
  document.addEventListener("turbolinks:load", function() {
    init_masonry();
  });
  init_masonry();

  test = new test();
  console.log(test);

});

function init_masonry(){
  if($('.grid') != undefined){
    var grid = new masonry('.grid', {
    // var $grid = $('.grid').masonry({
      // options
      // set itemSelector so .grid-sizer is not used in layout
      itemSelector: '.grid-item',
      // use element for option
      columnWidth: '.grid-sizer',
      gutter: '.gutter-sizer',
      percentPosition: true
    });
  }
}
