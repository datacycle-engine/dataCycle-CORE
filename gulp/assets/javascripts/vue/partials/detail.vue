<template>
  <div v-if="item.id != undefined">
    <h5>Details</h5>
    <div v-if="objectType != 'Ort'">
      <dl>
        <dt v-if="item.metadata.thumbnailUrl != undefined"></dt>
        <dd v-if="item.metadata.thumbnailUrl != undefined">
          <img :src=" item.metadata.thumbnailUrl ">
        </dd>
        <dt v-if="headline != undefined">Name: </dt>
        <dd v-if="headline != undefined">{{ headline }}</dd>
        <dt v-if="item.metadata.url != undefined">Datei Url: </dt>
        <dd v-if="item.metadata.url != undefined">
          <a :href="item.metadata.url " target="_blank ">{{ item.metadata.url }}</a>
        </dd>
        <dt v-if="item.metadata.fileFormat != undefined">Format: </dt>
        <dd v-if="item.metadata.fileFormat != undefined">{{ item.metadata.fileFormat }}</dd>
        <dt v-if="item.content.jobTitle != undefined">Beruf: </dt>
        <dd v-if="item.content.jobTitle != undefined">{{ item.content.jobTitle }}</dd>
        <dt v-if="item.metadata.width != undefined && item.metadata.height != undefined">Abmessungen: </dt>
        <dd v-if="item.metadata.width != undefined && item.metadata.height != undefined">{{ item.metadata.width }} x {{ item.metadata.height }}</dd>
        <dt v-if="item.metadata.contentSize != undefined">Dateigröße: </dt>
        <dd v-if="item.metadata.contentSize != undefined">{{ formatSize(item.metadata.contentSize) }}</dd>
        <dt v-if="item.metadata.license != undefined">Lizenz: </dt>
        <dd v-if="item.metadata.license != undefined">{{ item.metadata.license }}</dd>
        <dt v-if="item.metadata.dateCreated != undefined">Erstellt: </dt>
        <dd v-if="item.metadata.dateCreated != undefined">{{ formatDate(item.metadata.dateCreated) }}</dd>
        <dt v-if="item.metadata.dateModified != undefined">Bearbeitet: </dt>
        <dd v-if="item.metadata.dateModified != undefined">{{ formatDate(item.metadata.dateModified) }}</dd>
      </dl>
    </div>
    <div v-else>
      <dl>
        <dt v-if="headline != undefined">Name: </dt>
        <dd v-if="headline != undefined">{{ headline }}</dd>
        <dt v-if="item.address != undefined">Adresse: </dt>
        <dd v-if="item.address != undefined">{{ item.address }}</dd>
      </dl>
    </div>
  </div>
  <div v-else></div>
</template>
<script>
import Formatter from './../mixins/formatters.js'

export default {
  mixins: [Formatter],
  props: {
    item: {
      type: Object
    },
    headline: {
      type: String
    },
    objectType: {
      type: String
    }
  }
}
</script>
