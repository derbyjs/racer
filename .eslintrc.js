module.exports = {
  extends: 'xo',
  rules: {
    'block-scoped-var': 'off',
    'curly': ['error', 'multi-line', 'consistent'],
    'eqeqeq': ['error', 'allow-null'],
    'guard-for-in': 'off',
    'indent': ['error', 2, {SwitchCase: 1}],
    'max-len': ['off', 80, 4, {
      ignoreComments: true,
      ignoreUrls: true
    }],
    'no-eq-null': 'off',
    'no-implicit-coercion': 'off',
    'no-nested-ternary': 'off',
    'no-redeclare': 'off',
    'no-undef-init': 'off',
    'no-unused-expressions': ['error', {allowShortCircuit: true}],
    'one-var': ['error', {initialized: 'never'}],
    'require-jsdoc': 'off',
    'space-before-function-paren': ['error', 'never'],
    'valid-jsdoc': ['off', {
      requireReturn: false,
      prefer: {
        returns: 'return'
      }
    }],
  }
};
