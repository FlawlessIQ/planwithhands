// Export only the createAccount function to avoid config conflicts
module.exports = {
  ...require("./createAccount"),
};
