import { Model } from './Model';

declare module './Model' {
  interface Model {
    createConnection(backend: any, req?: any): void;
    connect(): void;
    connection: any;
  }
}

Model.prototype.createConnection = function(backend, req) {
  this.root.backend = backend;
  this.root.req = req;
  this.root.connection = backend.connect(null, req);
  this.root.socket = this.root.connection.socket;
  // Pretend like we are always connected on the server for rendering purposes
  this._set(['$connection', 'state'], 'connected');
  this._finishCreateConnection();
};

Model.prototype.connect = function() {
  this.root.backend.connect(this.root.connection, this.root.req);
  this.root.socket = this.root.connection.socket;
};
