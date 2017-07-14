<template>
  <span>
    {{ headline }}
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
      return this.item.content != undefined && this.item.content.headline != "" ? this.item.content.headline : "namenloses Bild";
    }
  }
}
</script>
