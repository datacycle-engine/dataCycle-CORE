import { defineConfig } from 'vite';
import RubyPlugin from 'vite-plugin-ruby';
import { resolve } from 'path';
import CopyPlugin from 'rollup-plugin-copy';
import DelPlugin from 'rollup-plugin-delete';

export default defineConfig({
  build: {
    brotliSize: false
  },
  plugins: [
    RubyPlugin(),
    DelPlugin({
      targets: ['app/assets/entrypoints/images'],
      hook: 'buildStart',
      runOnce: true
    }),
    CopyPlugin({
      targets: [
        { src: resolve(__dirname, 'app/assets/images/*'), dest: 'app/assets/entrypoints/images' },
        { src: resolve(__dirname, 'app/assets/fonts/*'), dest: 'public/assets/fonts' },
        { src: 'app/assets/images/*', dest: 'app/assets/entrypoints/images' }
      ],
      hook: 'generateBundle',
      copyOnce: true
    })
  ]
});
