var New = require('./new.vue');

var bild_chosen = require('./bild/chosen.vue');
var bild_detail = require('./bild/detail.vue');

var contentlocation_chosen = require('./contentlocation/chosen.vue');
var contentlocation_detail = require('./contentlocation/detail.vue');

var person_chosen = require('./person/chosen.vue');
var person_detail = require('./person/detail.vue');

module.exports = {
  components: {
    New,
    bild_chosen,
    bild_detail,
    contentlocation_chosen,
    contentlocation_detail,
    person_chosen,
    person_detail
  }
}