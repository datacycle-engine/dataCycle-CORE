var gulp         = require('gulp');
var handleErrors = require('../util/handleErrors');
var config       = require('../config').icons;

gulp.task('icons', function() {
    return gulp.src(config.src)
        .pipe(gulp.dest(config.dest));
});
