module.exports = {
  makeConfigurable: makeConfigurable
};

function makeConfigurable (module, envs) {
  if (envs) {
    if (!Array.isArray(envs)) envs = [envs];
  } else {
    envs = [];
  }

  module.settings || (module.settings = {});

  module.configure = function (env, callback) {
    if (typeof env === 'function') {
      callback = env;
      env = 'all';
    }
    if ((env === 'all') || ~envs.indexOf(env)) {
      callback.call(this);
    }
    return this;
  };

  module.set = function (setting, value) {
    this.settings[setting] = value;
    return this;
  };
  module.enable = function (setting) {
    return this.set(setting, true);
  };
  module.disable = function (setting) {
    return this.set(setting, false);
  };

  module.get = function (setting) {
    return this.settings[setting];
  };
  module.enabled = function (setting) {
    return !!this.get(setting);
  };
  module.disabled = function (setting) {
    return !this.get(setting);
  };

  module.applyConfiguration = function (configurable) {
    for (var setting in this.settings) {
      configurable.set(setting, this.settings[setting]);
    };
  };
}
