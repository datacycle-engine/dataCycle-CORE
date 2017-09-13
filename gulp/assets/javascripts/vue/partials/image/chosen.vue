<template>
  <div class="chosen-bg" :style="{ backgroundImage: 'url('+item.metadata.thumbnailUrl+')' }"></div>
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