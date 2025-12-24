module.exports = {
  root: true,
  extends: [
    "eslint:recommended",
    "next/core-web-vitals",
    "plugin:import/errors",
    "plugin:import/warnings",
    "plugin:import/typescript",
    "google",
    "plugin:@typescript-eslint/recommended",
  ],
  parser: "@typescript-eslint/parser",
  parserOptions: {
    project: ["tsconfig.json"],
    sourceType: "module",
  },
  ignorePatterns: [
    "/lib/**/*", // Ignore built files.
  ],
  plugins: ["@typescript-eslint", "import"],
  rules: {
    // Relax stylistic rules to avoid blocking CI/build on Windows line endings
    quotes: ["error", "single", { avoidEscape: true }],
    "import/no-unresolved": 0,
    "@typescript-eslint/no-explicit-any": "off",
    "linebreak-style": 0,
    "max-len": 0,
    "require-jsdoc": 0,
    "object-curly-spacing": 0,
    "arrow-parens": 0,
    indent: 0,
    "comma-dangle": 0,
    "eol-last": 0,
    "no-trailing-spaces": 0,
    "new-cap": 0,
    "valid-jsdoc": 0,
    "operator-linebreak": 0,
    "react/no-unescaped-entities": 0,
  },
};