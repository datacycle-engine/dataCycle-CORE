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
      return this.item.headline ? this.item.headline : "namenloses Bild";
    }
  }
}
</script>
