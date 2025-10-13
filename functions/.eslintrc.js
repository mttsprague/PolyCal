module.exports = {
  root: true,
  env: {
    es6: true,
    node: true,
  },
  extends: [
    "eslint:recommended",
    "plugin:import/errors",
    "plugin:import/warnings",
    "plugin:import/typescript",
    "google",
    "plugin:@typescript-eslint/recommended",
  ],
  parser: "@typescript-eslint/parser",
  parserOptions: {
    project: ["tsconfig.json", "tsconfig.dev.json"],
    sourceType: "module",
  },
  ignorePatterns: [
    "/lib/**/*", // Ignore built files.
    "/generated/**/*", // Ignore generated files.
  ],
  plugins: [
    "@typescript-eslint",
    "import",
  ],
  rules: {
    // Standard rules
    "quotes": ["error", "double"],
    "indent": ["error", 2],
    "import/no-unresolved": 0, // Often needed for Firebase module imports

    // --- Custom rules to address common Firebase Functions ESLint issues ---

    // Increase max-len to 120 and ignore strings/template literals
    // This often prevents issues with long error messages or URLs
    "max-len": ["error", {"code": 120, "ignoreRegExpLiterals": true, "ignoreStrings": true, "ignoreTemplateLiterals": true, "ignoreComments": true}],

    // Disable the default 'no-unused-vars' and use the TypeScript version
    // Allows ignoring unused variables that start with an underscore (e.g., _req)
    "no-unused-vars": "off",
    "@typescript-eslint/no-unused-vars": ["error", {"argsIgnorePattern": "^_"}],

    // Allow explicit 'any' type, which is sometimes necessary or convenient
    // in complex Firebase Function scenarios or when interfacing with external libraries.
    // Consider tightening this rule later if type safety becomes a higher priority.
    "@typescript-eslint/no-explicit-any": "off",

    // Allow console.log for debugging purposes in development.
    // For production, consider using functions.logger.info/warn/error and eventually
    // disabling 'no-console' for cleaner logs.
    "no-console": "off",
  },
};
