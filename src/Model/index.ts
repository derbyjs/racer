/// <reference path="./bundle.ts" preserve="true" />
/// <reference path="./connection.server.ts" preserve="true" />

import { serverRequire } from '../util';
export { Model, ChildModel, RootModel, type ModelOptions, type UUID, type DefualtType } from './Model';
export { ModelData } from './collections';
export { type Subscribable } from './subscriptions';

// Extend model on both server and client //
import './unbundle';
import './events';
import './paths';
import './collections';
import './mutators';
import './setDiff';

import './connection';
import './subscriptions';
import './Query';
import './contexts';

import './fn';
import './filter';
import './refList';
import './ref';

// Extend model for server //
serverRequire(module, './bundle');
serverRequire(module, './connection.server');
