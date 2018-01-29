var gulp         = require('gulp');
var fontello     = require('gulp-fontello');
var print        = require('gulp-print');
var handleErrors = require('../util/handleErrors');
var config       = require('../config').fontello;

gulp.task('fontello', function () {
    return gulp.src(config.fontelloConfig)
        .pipe(fontello())
        .pipe(print())
        .pipe(gulp.dest(config.dest))
});