var $ = require('jquery');
var jqueryujs = require('jquery-ujs');
var foundation = require('foundation-sites');
// var turbolinks = require('turbolinks');
var masonry = require('masonry-layout');

Vue = require('vue');
App = require('./vue/app.vue');

/*
Init
*/
// turbolinks = new turbolinks.start();

$(function(){
  $(document).foundation();
  // document.addEventListener("turbolinks:load", function() {
  //   init_masonry();
  // });
  init_masonry();

  //testing
  appOne = new Vue({
    el: '#app',
    data: {
      message: 'Hello Vue!'
    }
  })


  newApp = new Vue({
    el: '#app2',
    template: '<App/>',
    components: { App },
    // render: function (createElement) {
    //   return createElement(App)
    // }
  })

});

function init_masonry(){
  if($('.grid').html() != undefined){
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
