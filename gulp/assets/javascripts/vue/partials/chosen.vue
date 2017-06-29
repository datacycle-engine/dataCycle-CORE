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
    },
    headline: {
      type: String
    }
  }
}
</script>
