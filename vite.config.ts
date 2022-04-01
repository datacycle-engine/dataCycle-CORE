import RubyPlugin from 'vite-plugin-ruby';
import { resolve } from 'path';
import CopyPlugin from 'rollup-plugin-copy';
import DelPlugin from 'rollup-plugin-delete';
import gzipPlugin from 'rollup-plugin-gzip';

export default ({ mode }) => {
  return {
    build: {
      chunkSizeWarningLimit: 5000,
      brotliSize: false,
      minify: mode == 'development' ? false : 'terser',
      rollupOptions: {
        output: {
          manualChunks: undefined
        }
      }
    },
    plugins: [
      RubyPlugin(),
      CopyPlugin({
        targets: [
          { src: resolve(__dirname, 'app/assets/images/*'), dest: 'app/assets/entrypoints/images' },
          { src: resolve(__dirname, 'app/assets/fonts/*'), dest: 'public/assets/fonts' },
          { src: 'app/assets/images/*', dest: 'app/assets/entrypoints/images' }
        ],
        hook: 'buildStart',
        copyOnce: true
      }),
      DelPlugin({
        targets: ['app/assets/entrypoints/images'],
        hook: 'closeBundle',
        runOnce: true
      }),
      ...(mode == 'development' ? [] : [gzipPlugin()])
    ]
  };
};
