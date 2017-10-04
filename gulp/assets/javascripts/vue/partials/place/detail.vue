<template>
  <div v-if="item.id != undefined">
    <h5>Details</h5>
    <a :href="editLink" target="_blank" class="edit-link">
      <i class="fa fa-pencil" aria-hidden="true"></i>
    </a>
    <dl>
      <dt v-if="item.name != undefined">Name: </dt>
      <dd v-if="item.name != undefined">{{ item.name }}</dd>
      <dt v-if="item.street_address != undefined">Straße: </dt>
      <dd v-if="item.street_address != undefined">{{ item.street_address }}</dd>
      <dt v-if="item.postal_code != undefined">PLZ: </dt>
      <dd v-if="item.postal_code != undefined">{{ item.postal_code }}</dd>
      <dt v-if="item.address_locality != undefined">Ort: </dt>
      <dd v-if="item.address_locality != undefined">{{ item.address_locality }}</dd>
      <dt v-if="item.latitude != undefined">Latitude: </dt>
      <dd v-if="item.latitude != undefined">{{ item.latitude }}</dd>
      <dt v-if="item.longitude != undefined">Longitude: </dt>
      <dd v-if="item.longitude != undefined">{{ item.longitude }}</dd>
    </dl>
  </div>
  <div v-else></div>
</template>
<script>
import Formatter from './../../mixins/formatters.js'

export default {
  mixins: [Formatter],
  props: {
    item: {
      type: Object
    },
    link: {
      type: String
    }
  },
  computed: {
    editLink() {
      return this.link + "/" + this.item.id + "/edit";
    }
  }

}
</script>
