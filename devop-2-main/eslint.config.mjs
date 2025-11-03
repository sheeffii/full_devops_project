/* eslint-env node */
import js from "@eslint/js";
import globals from "globals";
import { defineConfig } from "eslint/config";

export default defineConfig([
  {
    files: ["**/*.{js,mjs,cjs}"],
    languageOptions: {
      globals: {
        ...globals.node, // use Node.js globals
      },
      sourceType: "commonjs", // use require() syntax
    },
    plugins: {
      js,
    },
    extends: ["js/recommended"],
  },
]);
