import { defineConfig } from 'vite'
import RubyPlugin from 'vite-plugin-ruby'
import path from 'path';

export default defineConfig({
  build: {
    rollupOptions: {
      input: {
        application: path.resolve('gulp/assets/javascripts/app.js'),
        core: path.resolve('vendor/gems/data-cycle-core/app/frontend/entrypoints/application.js')
      }
    }
  },
  plugins: [
    RubyPlugin(),
  ],
})
