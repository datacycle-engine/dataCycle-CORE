<template>
  <div class="chosen-bg" :style="{ backgroundImage: 'url('+item.metadata.thumbnail_url+')' }"></div>
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