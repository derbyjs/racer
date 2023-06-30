import { RacerBackend } from './Backend';
import { Racer } from './Racer';

declare module './Racer' {
  interface Racer {
    Backend: typeof RacerBackend;
    version: string;
    createBackend: (options:any) => RacerBackend;
  }
}

Racer.prototype.Backend = RacerBackend;

Racer.prototype.version = require('../package').version;

Racer.prototype.createBackend = function(options) {
  return new RacerBackend(this, options);
};
