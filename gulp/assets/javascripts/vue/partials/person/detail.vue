<template>
  <div v-if="item.id != undefined">
    <h5>Details</h5>
    <a :href="editLink" target="_blank" class="edit-link">
      <i class="fa fa-pencil" aria-hidden="true"></i>
    </a>
    <dl>
      <dt v-if="item.givenName != undefined && item.familyName != undefined">Name: </dt>
      <dd v-if="item.givenName != undefined && item.familyName != undefined">{{ item.givenName }}
        <b> {{ item.familyName }}</b>
      </dd>
      <dt v-if="item.content != undefined && item.content.jobTitle != undefined">Beruf: </dt>
      <dd v-if="item.content != undefined && item.content.jobTitle != undefined">{{ item.content.jobTitle }}</dd>
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
