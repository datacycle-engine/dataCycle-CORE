var New = require('./new.vue');

var image_chosen = require('./image/chosen.vue');
var image_detail = require('./image/detail.vue');

var video_chosen = require('./video/chosen.vue');
var video_detail = require('./video/detail.vue');

var place_chosen = require('./place/chosen.vue');
var place_detail = require('./place/detail.vue');

var person_chosen = require('./person/chosen.vue');
var person_detail = require('./person/detail.vue');

module.exports = {
  components: {
    New,
    image_chosen,
    image_detail,
    place_chosen,
    place_detail,
    person_chosen,
    person_detail,
    video_chosen,
    video_detail
  }
}
