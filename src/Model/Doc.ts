import { type Model } from './Model';
import { Collection } from './collections';
import { Path } from '../types';

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

  path(segments?: Path[]) {
    var path = this.collectionName + '.' + this.id;
    if (segments && segments.length) path += '.' + segments.join('.');
    return path;
  };
  
  _errorMessage(description: string, segments: Path[], value: any) {
    return description + ' at ' + this.path(segments) + ': ' +
      JSON.stringify(value, null, 2);
  };
}
