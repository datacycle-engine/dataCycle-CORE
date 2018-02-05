var gulp         = require('gulp');
var handleErrors = require('../util/handleErrors');
var config       = require('../config').images;

gulp.task('images', function() {
    return gulp.src(config.src)
        .pipe(gulp.dest(config.dest));
});
