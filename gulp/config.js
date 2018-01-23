var publicAssets = "./lib/assets";
var sourceFiles = "./gulp/assets";

var nodeModulesSource = "./node_modules";
var iconDest = "./lib/assets/fonts";

module.exports = {
  publicAssets: publicAssets,
  browserSync: {
    proxy: 'localhost:3000',
    files: ['./app/views/**'],
    open: false
  },
  images: {
      src: sourceFiles + "/images/**/*.{png,jpg,jpeg,gif,svg}",
      dest: "public/assets/images"
  },
  sass: {
    src: sourceFiles + "/stylesheets/**/*.{sass,scss}",
    dest: publicAssets + "/stylesheets",
    settings: {
      imagePath: '/assets/images' // Used by the image-url helper
    }
  },
  icons: {
    src: nodeModulesSource + "/font-awesome/fonts/**.*",
    // dest: publicAssets + "/fonts",
    dest: iconDest,
  },
  fontello: {
      fontelloConfig: './gulp/fontello/config.json',
      src: nodeModulesSource + "/font-awesome/fonts/**.*",
      // dest: publicAssets + "/fonts",
      dest: iconDest,
  },
  browserify: {
    bundleConfigs: [{
      entries: sourceFiles + '/javascripts/app.js',
      dest: publicAssets + '/javascripts',
      outputName: 'app.js',
      extensions: ['.js','.coffee']
    }]
  }
};
