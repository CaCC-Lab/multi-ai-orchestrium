const path = require('path');
const dotenv = require('dotenv');

let loaded = false;

const loadEnv = () => {
  if (loaded) {
    return;
  }

  const envFile = path.resolve(process.cwd(), '.env');
  const result = dotenv.config({ path: envFile });

  if (result.error) {
    // eslint-disable-next-line no-console
    console.warn('[env] Unable to load .env file, relying on process environment variables');
  }

  loaded = true;
};

const getEnv = (key, defaultValue = undefined) => {
  return process.env[key] !== undefined ? process.env[key] : defaultValue;
};

module.exports = {
  loadEnv,
  getEnv,
};
