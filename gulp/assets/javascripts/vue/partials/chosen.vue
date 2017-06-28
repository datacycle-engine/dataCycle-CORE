<template>
  <span>
    {{ item.content.headline }}
  </span>
</template>

<script>
export default {
  props: {
    item: {
      type: Object
    }
  }
}
</script>
