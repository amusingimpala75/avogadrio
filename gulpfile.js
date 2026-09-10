import Promise from 'es6-promise';

import gulp from 'gulp';

import less from 'gulp-less';
import cleanCSS from 'gulp-clean-css';
import autoprefixer from 'gulp-autoprefixer';
import coffee from 'gulp-coffee';

// Compile all the Less.
gulp.task('less', function () {
    return gulp.src(['./src/less/*.less'])
        .pipe(less())
        .pipe(autoprefixer(
            "last 1 version", "> 1%", "ie 8", "ie 7"
        ))
        .pipe(cleanCSS({compatibility: 'ie8'})) // Minify resulting CSS.
        .pipe(gulp.dest('./web/css'));
});

// Compile all the CoffeeScript.
gulp.task('coffee', function () {
    return gulp.src(['./src/coffee/*.coffee'])
        .pipe(coffee())
        .pipe(gulp.dest('./web/js'));
});

gulp.task('watch', function() {
    // Compile Less.
    gulp.watch("./src/less/*.less", function(event) {
        gulp.run('less');
    });
    // Compile CoffeeScript.
    gulp.watch("./src/coffee/*.coffee", function(event) {
        gulp.run('coffee');
    });
});

gulp.task('default', gulp.series('less', 'coffee'));
