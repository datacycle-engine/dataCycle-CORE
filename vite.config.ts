import RubyPlugin from 'vite-plugin-ruby';
import { resolve } from 'path';
import gzipPlugin from 'rollup-plugin-gzip';

export default ({ mode }) => {
  return {
    resolve: {
      alias: {
        '@core_assets': resolve(__dirname, 'app/assets') // will be replaced with the correct path to self https://vitejs.dev/config/#config-file-resolving
      }
    },
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
    plugins: [RubyPlugin(), ...(mode == 'development' ? [] : [gzipPlugin()])]
  };
};
