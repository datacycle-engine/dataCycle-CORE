import RubyPlugin from 'vite-plugin-ruby';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';
import gzipPlugin from 'rollup-plugin-gzip';
const _dirname = dirname(fileURLToPath(import.meta.url));

export default ({ mode }) => {
  return {
    resolve: {
      alias: {
        '@core_assets': resolve(_dirname, 'app/assets')
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
