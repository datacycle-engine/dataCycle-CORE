import RubyPlugin from "vite-plugin-ruby";
import { resolve } from "path";
import gzipPlugin from "rollup-plugin-gzip";

export default ({ mode }) => {
	return {
		resolve: {
			alias: {
				"@core_assets": resolve(__dirname, "app/assets"),
			},
			// host projects import these assets by relative path, so a nested
			// node_modules here would otherwise give plugins their own jQuery.
			dedupe: ["jquery"],
		},
		build: {
			chunkSizeWarningLimit: 5000,
			brotliSize: false,
		},
		plugins: [RubyPlugin(), ...(mode === "development" ? [] : [gzipPlugin()])],
	};
};
