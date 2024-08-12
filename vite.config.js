import RubyPlugin from "vite-plugin-ruby";
import { resolve } from "path";
import gzipPlugin from "rollup-plugin-gzip";

export default ({ mode }) => {
	return {
		resolve: {
			alias: {
				"@core_assets": resolve(__dirname, "app/assets"),
			},
		},
		build: {
			chunkSizeWarningLimit: 5000,
			brotliSize: false,
		},
		plugins: [RubyPlugin(), ...(mode === "development" ? [] : [gzipPlugin()])],
	};
};
