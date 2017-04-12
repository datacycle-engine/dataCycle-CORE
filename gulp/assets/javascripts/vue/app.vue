<template>
    <div>
        <h1>{{ msg }}</h1>
        <Hello></Hello>
    </div>
</template>

<script>
    import Hello from './components/hello.vue'

    export default {
    name:'vueApplication',
      data () {
          return {
              msg: 'Welcome to Vue.js World!'
          }
      },
      components: {
          Hello
      }
    }
</script>

<style>
  
</style>
