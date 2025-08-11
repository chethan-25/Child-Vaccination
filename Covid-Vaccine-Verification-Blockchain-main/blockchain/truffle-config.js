module.exports = {
  networks: {
    development: {
      host: "127.0.0.1",
      port: 7545,
      network_id: "1337", // Ganache default
      gas: 6721975,
      gasPrice: 20000000000,
      from: undefined, // Use first account in Ganache
    },
    ganache: {
      host: "127.0.0.1",
      port: 7545,
      network_id: "1337",
      gas: 6721975,
      gasPrice: 20000000000,
    }
  },

  mocha: {
    timeout: 100000
  },

  compilers: {
    solc: {
      version: "0.8.19",
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
        evmVersion: "byzantium"
      }
    }
  },

  db: {
    enabled: false
  }
};