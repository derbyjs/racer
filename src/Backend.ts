import * as path from 'path';
import * as util from './util';
import { type ModelOptions, RootModel } from './Model/Model';
import Backend = require('sharedb');

export type BackendOptions = { modelOptions?: ModelOptions } & Backend.ShareDBOptions;

/**
 * RacerBackend extends ShareDb Backend
 */
export class RacerBackend extends Backend {
  racer: any;
  modelOptions: ModelOptions;

  /**
   * 
   * @param racer - Racer instance
   * @param options - Model and SharedB options 
   */
  constructor(racer: any, options?: BackendOptions) {
    super(options);
    this.racer = racer;
    this.modelOptions = options && options.modelOptions;
    this.on('bundle', function (browserify) {
      var racerPath = path.join(__dirname, 'index.js');
      browserify.require(racerPath, { expose: 'racer' });
    });
  }

  /**
   * Create new `RootModel`
   *
   * @param options - Optional model options
   * @param request - Optional request context See {@link Backend.listen} for details.
   * @returns a new root model
   */
  createModel(options?: ModelOptions, request?: any) {
    if (this.modelOptions) {
      options = (options) ?
        util.mergeInto(options, this.modelOptions) :
        this.modelOptions;
    }
    var model = new RootModel(options);
    this.emit('model', model);
    model.createConnection(this, request);
    return model;
  };

  /**
   * Model middleware that creates and attaches a {@link Model} to the `request`
   * and attaches listeners to response for closing model on response completion
   *
   * @returns an Express middleware function
   */
  modelMiddleware() {
    var backend = this;
    function modelMiddleware(req, res, next) {
      // Do not add a model to the request if one has been added already
      if (req.model) return next();

      // Create a new model for this request
      req.model = backend.createModel({ fetchOnly: true }, req);

      // Close the model when this request ends
      function closeModel() {
        res.removeListener('finish', closeModel);
        res.removeListener('close', closeModel);
        if (req.model) req.model.close();
      }
      res.on('finish', closeModel);
      res.on('close', closeModel);

      next();
    }
    return modelMiddleware;
  };
}

function getModelUndefined() { }
