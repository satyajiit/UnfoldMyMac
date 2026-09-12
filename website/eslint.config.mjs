import { fixupConfigRules } from "@eslint/compat";
import { defineConfig, globalIgnores } from "eslint/config";
import nextVitals from "eslint-config-next/core-web-vitals";
import nextTs from "eslint-config-next/typescript";
export default defineConfig([...fixupConfigRules([...nextVitals, ...nextTs]), globalIgnores([".next/**", "out/**", "test-results/**", "playwright-report/**", "next-env.d.ts"])]);
