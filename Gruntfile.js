module.exports = function(grunt) {

  grunt.initConfig({
    jshint: {
      options: {
        laxcomma: true
      , eqnull: true
      , eqeqeq: true
      , indent: 2
      , newcap: true
      , quotmark: 'single'
      , undef: true
      , trailing: true
      , supernew: true
      , funcscope: true
      , shadow: true
      , expr: true
      , node: true
      }
    , all: ['Gruntfile.js', 'lib/**/*.js']
    }
  , simplemocha: {
      options: {
        reporter: 'spec'
      }
    , all: {
        src: 'test/**/*.mocha.coffee'
      }
    }
  });

  grunt.loadNpmTasks('grunt-simple-mocha');
  grunt.loadNpmTasks('grunt-contrib-jshint');
  grunt.registerTask('test', ['jshint', 'simplemocha']);
};
