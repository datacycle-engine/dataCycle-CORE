<template>
  <div v-if="item.id != undefined">
    <h5>Details</h5>
    <dl v-if="item.headline">
      <dt>Name: </dt>
      <dd>{{ item.headline }}</dd>
    </dl>
    <dl v-if="item.metadata != undefined">
      <dt class="block-flex" v-if="item.metadata.thumbnailUrl != undefined"></dt>
      <dd class="block-flex" v-if="item.metadata.thumbnailUrl != undefined">
        <img :src=" item.metadata.thumbnailUrl ">
      </dd>
      <dt class="block-flex" v-if="item.metadata.url != undefined">Datei Url: </dt>
      <dd class="block-flex" v-if="item.metadata.url != undefined">
        <a :href="item.metadata.url " target="_blank ">{{ item.metadata.url }}</a>
      </dd>
      <dt v-if="item.metadata.fileFormat != undefined">Format: </dt>
      <dd v-if="item.metadata.fileFormat != undefined">{{ item.metadata.fileFormat }}</dd>
      <dt v-if="item.metadata.width != undefined && item.metadata.height != undefined">Abmessungen: </dt>
      <dd v-if="item.metadata.width != undefined && item.metadata.height != undefined">{{ item.metadata.width }} x {{ item.metadata.height }}</dd>
      <dt v-if="item.metadata.contentSize != undefined">Dateigröße: </dt>
      <dd v-if="item.metadata.contentSize != undefined">{{ formatSize(item.metadata.contentSize) }}</dd>
      <dt class="block-flex" v-if="item.metadata.license != undefined">Lizenz: </dt>
      <dd class="block-flex" v-if="item.metadata.license != undefined">{{ item.metadata.license }}</dd>
      <dt class="block-flex" v-if="item.metadata.restrictions != undefined && item.metadata.restrictions != '' && item.metadata.restrictions != 'Keine Einschränkung;'">Einschränkungen: </dt>
      <dd class="block-flex" v-if="item.metadata.restrictions != undefined && item.metadata.restrictions != '' && item.metadata.restrictions != 'Keine Einschränkung;'"><i class="fa fa-exclamation-triangle" aria-hidden="true"></i> {{ item.metadata.restrictions }}</dd>
      <dt v-if="item.metadata.dateCreated != undefined">Erstellt: </dt>
      <dd v-if="item.metadata.dateCreated != undefined">{{ formatDate(item.metadata.dateCreated) }}</dd>
      <dt v-if="item.metadata.dateModified != undefined">Bearbeitet: </dt>
      <dd v-if="item.metadata.dateModified != undefined">{{ formatDate(item.metadata.dateModified) }}</dd>
    </dl>
  </div>
  <div v-else></div>
</template>
<script>
import Formatter from './../../mixins/formatters.js'

export default {
  mixins: [Formatter],
  props: {
    item: {
      type: Object
    }
  }
}
</script>
