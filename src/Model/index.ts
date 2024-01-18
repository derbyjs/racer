/// <reference path="./bundle.ts" />
/// <reference path="./connection.server.ts" />

import { serverRequire } from '../util';
export { Model, ChildModel, RootModel } from './Model';
export { ModelData } from './collections';

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
