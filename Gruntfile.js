module.exports = function(grunt) {

  grunt.initConfig(
  { jshint:
    { src:
      [ 'Gruntfile.js'
      , 'lib/**/*.js'
      ]
    , options:
      { jshintrc: '.jshintrc'
      }
    }
  , simplemocha:
    { options:
      { reporter: 'spec'
      }
    , all:
      { src: 'test/**/*.mocha.coffee'
      }
    }
  });

  grunt.loadNpmTasks('grunt-simple-mocha');
  grunt.loadNpmTasks('grunt-contrib-jshint');
  grunt.registerTask('test', ['jshint', 'simplemocha']);
};
