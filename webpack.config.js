module.exports = {
  resolve: {
    fallback: {
      process: require.resolve("process/browser"),
      stream: require.resolve("stream-browserify"),
      assert: require.resolve("assert/"),
      http: require.resolve("stream-http"),
      os: require.resolve("os-browserify/browser"),
      url: require.resolve("url/"),
      https: require.resolve("https-browserify"),
      http: require.resolve("stream-http"),
    },
  },
};
