var gulp = require('gulp');

gulp.task('production', ['build','sass', 'icons', 'browserify']);
