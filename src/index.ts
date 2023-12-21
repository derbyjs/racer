import { Racer } from './Racer';
import { Model } from './Model';
import * as util from './util';
import { RacerBackend } from './Backend';
import { Query } from './Model/Query';
import { ModelData } from './Model'

// module.exports = new Racer();
const { use, serverUse } = util;

export { Model };
export { type ModelData }
export { Query };
export { Racer };
export { RacerBackend };
export { use, serverUse };
export { util };
export const racer = new Racer();

export function createModel(data) {
  var model = new Model();
  if (data) {
    model.createConnection(data);
    model.unbundle(data);
  }
  return model;
}

export function createBackend(options) {
  return new RacerBackend(racer, options);
};
