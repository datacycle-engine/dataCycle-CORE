var publicAssets = "./public/assets";
var sourceFiles  = "./gulp/assets";

module.exports = {
  publicAssets: publicAssets,
  browserSync: {
    proxy: 'localhost:3000',
    files: ['./app/views/**'],
    open: false
  },
  sass: {
    src: sourceFiles + "/stylesheets/**/*.{sass,scss}",
    dest: publicAssets + "/stylesheets",
    settings: {
      imagePath: '/assets/images' // Used by the image-url helper
    }
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
