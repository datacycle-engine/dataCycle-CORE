import { defineConfig } from 'vite';
import RubyPlugin from 'vite-plugin-ruby';
import { resolve } from 'path';
import CopyPlugin from 'rollup-plugin-copy';
import DelPlugin from 'rollup-plugin-delete';

export default defineConfig({
  plugins: [
    RubyPlugin(),
    DelPlugin({
      targets: ['app/assets/entrypoints/images'],
      hook: 'buildStart'
    }),
    CopyPlugin({
      targets: [
        { src: 'app/assets/images/*', dest: 'app/assets/entrypoints/images' },
        { src: resolve(__dirname, 'app/assets/images/*'), dest: 'app/assets/entrypoints/images' },
        { src: resolve(__dirname, 'app/assets/fonts/*'), dest: 'public/assets/fonts' }
      ],
      hook: 'generateBundle'
    })
  ]
});
