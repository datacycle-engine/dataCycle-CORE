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
      return this.item.name != undefined ? this.item.name : "namenloser Ort";
    }
  }
}
</script>
