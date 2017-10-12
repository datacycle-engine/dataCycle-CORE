<template>
  <div class="chosen-bg" :style="{ backgroundImage: 'url('+item.metadata.image+')' }">
  </div>
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
