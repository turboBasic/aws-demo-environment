export default {
  extends: ["@commitlint/config-conventional"],
  formatter: "@commitlint/format",
  rules: {
    "body-max-line-length": [2, "always", 100],
  },
  ignores: [
    (commit) => commit.startsWith("chore(deps): "),
  ],
  defaultIgnores: true,
}
