<template>
  <div v-if="item.id != undefined">
    <h5>Details</h5>
    <a :href="editLink" target="_blank" class="edit-link">
      <i class="fa fa-pencil" aria-hidden="true"></i>
    </a>
    <dl>
      <dt v-if="item.given_name != undefined && item.family_name != undefined">Name: </dt>
      <dd v-if="item.given_name != undefined && item.family_name != undefined">{{ item.given_name }}
        <b> {{ item.family_name }}</b>
      </dd>
    </dl>
    <dl v-if="item.content != undefined">
      <dt v-if="item.content.honorific_prefix != undefined">Titel: </dt>
      <dd v-if="item.content.honorific_prefix != undefined">{{ item.content.honorific_prefix }}</dd>
      <dt v-if="item.content.job_title != undefined">Beruf: </dt>
      <dd v-if="item.content.job_title != undefined">{{ item.content.job_title }}</dd>
    </dl>
    <dl v-if="item.metadata != undefined">
      <dt v-if="item.metadata.email != undefined">Email: </dt>
      <dd v-if="item.metadata.email != undefined">{{ item.metadata.email }}</dd>
      <dt v-if="item.metadata.telephone != undefined">Telefon: </dt>
      <dd v-if="item.metadata.telephone != undefined">{{ item.metadata.telephone }}</dd>
      <dt v-if="item.metadata.fax_number != undefined">Fax: </dt>
      <dd v-if="item.metadata.fax_number != undefined">{{ item.metadata.fax_number }}</dd>
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
