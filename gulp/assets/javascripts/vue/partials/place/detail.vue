<template>
  <div v-if="item.id != undefined">
    <h5>Details</h5>
    <a :href="editLink" target="_blank" class="edit-link">
      <i class="fa fa-pencil" aria-hidden="true"></i>
    </a>
    <dl>
      <dt v-if="item.name != undefined">Name: </dt>
      <dd v-if="item.name != undefined">{{ item.name }}</dd>
    </dl>
    <dl v-if="item.metadata != undefined && item.metadata.address != undefined">
      <dt v-if="item.metadata.address.streetAddress != undefined">Straße: </dt>
      <dd v-if="item.metadata.address.streetAddress != undefined">{{ item.metadata.address.streetAddress }}</dd>
      <dt v-if="item.metadata.address.postalCode != undefined">PLZ: </dt>
      <dd v-if="item.metadata.address.postalCode != undefined">{{ item.metadata.address.postalCode }}</dd>
      <dt v-if="item.metadata.address.addressLocality != undefined">Ort: </dt>
      <dd v-if="item.metadata.address.addressLocality != undefined">{{ item.metadata.address.addressLocality }}</dd>
    </dl>
    <dl>
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
