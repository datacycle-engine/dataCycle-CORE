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
      return this.item.given_name != undefined && this.item.family_name != undefined ? this.item.given_name + " <b>" + this.item.family_name + "</b>" : "namenlose Person";
    }
  }
}
</script>
