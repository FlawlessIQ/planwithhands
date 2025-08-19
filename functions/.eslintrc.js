module.exports = {
  env: {
    es6: true,
    node: true,
  },
  parserOptions: {
  "ecmaVersion": 2018,
  },
  extends: [
    "eslint:recommended",
    "google",
  ],
  rules: {
    "no-restricted-globals": ["error", "name", "length"],
    "prefer-arrow-callback": "error",
    "quotes": ["error", "double", {"allowTemplateLiterals": true}],
    "max-len": ["warn", {"code": 120}],
  },
  overrides: [
    // TypeScript files use the TypeScript ESLint parser and recommended rules
    {
      files: ["**/*.ts"],
      parser: "@typescript-eslint/parser",
      parserOptions: {
  project: './tsconfig.eslint.json',
        sourceType: 'module'
      },
      plugins: ["@typescript-eslint"],
      extends: [
        "plugin:@typescript-eslint/recommended"
      ],
      rules: {
        // allow explicit any in some migration/test code for now
        "@typescript-eslint/no-explicit-any": "off"
      }
    },
    {
      files: ["test/**"],
      env: { mocha: true },
      rules: {
        "@typescript-eslint/no-unused-expressions": "off"
      }
    },
    {
      files: ["**/*.spec.*"],
      env: {
        mocha: true,
      },
      rules: {},
    },
  ],
  globals: {},
};
