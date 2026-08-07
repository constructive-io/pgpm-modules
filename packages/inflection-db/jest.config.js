/** @type {import('ts-jest').JestConfigWithTsJest} */
module.exports = {
  forceExit: true,
    preset: "ts-jest",
    testEnvironment: "node",
    transform: {
        "^.+\\.tsx?$": [
            "ts-jest",
            {
                babelConfig: false,
            },
        ],
    },
    transformIgnorePatterns: [`/node_modules/*`],
    testRegex: "(/__tests__/.*|(\\.|/)(test|spec))\\.(jsx?|tsx?)$",
    moduleFileExtensions: ["ts", "tsx", "js", "jsx", "json", "node"],
    modulePathIgnorePatterns: ["dist/*"]
};
