import shared from "@gk/config/eslint/index.js";

export default [...shared, { ignores: ["dist/**", "coverage/**"] }];
