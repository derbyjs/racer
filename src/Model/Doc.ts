import { type Model } from './Model';
import { type Segments } from './types';
import { Collection } from './collections';

export class Doc {
  collectionData: Model;
  collectionName: string;
  data: any;
  id: string;
  model: Model;

  constructor(model: Model, collectionName: string, id: string, data?: any, _collection?: Collection) {
    this.collectionName = collectionName;
    this.id = id;
    this.data = data;
    this.model = model;
    this.collectionData = model && model.data[collectionName];
  }

  path(segments?: Segments) {
    var path = this.collectionName + '.' + this.id;
    if (segments && segments.length) path += '.' + segments.join('.');
    return path;
  };
  
  _errorMessage(description: string, segments: Segments, value: any) {
    return description + ' at ' + this.path(segments) + ': ' +
      JSON.stringify(value, null, 2);
  };
}
