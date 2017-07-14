<template>
  <div v-if="item.id != undefined">
    <h5>Details</h5>
    <dl>
      <dt v-if="item.name != undefined">Name: </dt>
      <dd v-if="item.name != undefined">{{ item.name }}</dd>
      <dt v-if="item.address != undefined">Adresse: </dt>
      <dd v-if="item.address != undefined">{{ item.address }}</dd>
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
    }
  }
}
</script>
