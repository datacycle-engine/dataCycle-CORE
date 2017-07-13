<template>
  <span v-html="headline">
  </span>
</template>

<script>
export default {
  props: {
    item: {
      type: Object
    }
  },
  computed: {
    headline() {
      return this.item.givenName != undefined && this.item.familyName != undefined ? this.item.givenName + " <b>" + this.item.familyName + "</b>" : "namenlose Person";
    }
  }
}
</script>
