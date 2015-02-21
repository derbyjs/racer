# Racer

Racer is a realtime model synchronization engine for Node.js. By leveraging [ShareJS](http://sharejs.org/), multiple users can interact with the same data in realtime via Operational Transformation, a sophisticated conflict resolution algorithm that works in realtime and with offline clients. ShareJS also supports PubSub across multiple servers for horizontal scaling. Clients can express data subscriptions and fetches in terms of queries and specific documents, so different clients can be subscribed to different overlapping sets of data. On top of this sophisticated backend, Racer provides a simple model and event interface for writing application logic.

[![Build Status](https://travis-ci.org/derbyjs/racer.svg)](https://travis-ci.org/derbyjs/racer)

## Disclaimer

Racer is alpha software. We are now on the road to a production ready version, but we are currently cleaning up the code, finishing loose ends, and testing.

If you are interested in contributing, please reach out to [Nate](https://github.com/nateps), [Joseph](https://github.com/josephg), and [Brian](https://github.com/bnoguchi).

## Demos

There are currently two demos, which are included in the [racer-examples](https://github.com/derbyjs/racer-examples) repo.

  * [Pad](https://github.com/derbyjs/racer-examples/tree/master/pad) &ndash; A very simple collaborative text editor.
  * [Todos](https://github.com/derbyjs/racer-examples/tree/master/todos) &ndash; Classic todo list demonstrating the use of Racer's model methods.

## Features

  * **Realtime updates** &ndash; Model methods automatically propagate changes among browser clients and Node servers in realtime. The [racer-browserchannel](https://github.com/codeparty/racer-browserchannel) adapter is recommended for connecting browsers in realtime.

  * **Realtime query subscriptions** &ndash; Clients may subscribe to a limited set of information relevant to the current session. Both document and realtime query subscriptions are supported. Currently, arbitrary Mongo queries are supported.

  * **Conflict resolution** &ndash; Leveraging ShareJS's JSON Operational Transformation algorithm, Racer will emit events that bring conflicting client states into eventual consistency. In addition to their synchronous API, model methods have callbacks for handling the resolved state after a server response.

  * **Immediate interaction** &ndash; Model methods appear to take effect immediately. Meanwhile, Racer sends updates to the server and checks for conflicts. If the updates are successful, they are stored and broadcast to other clients.

  * **Offline** &ndash; Since model methods are applied immediately, clients continue to work offline. Any changes to the local client or the global state automatically sync upon reconnecting.

  * **Unified server and client interface** &ndash; The same model interface can be used on the server for initial page rendering and on the client for user interaction. Racer supports bundling models created on the server and reinitializing them in the same state in the browser.

  * **Persistent storage** &ndash; Racer/ShareJS use [LiveDB](https://github.com/josephg/livedb) to keep a journal of all data operations, publish operations to multiple frontend servers, and automatically persist documents. It currently supports MongoDB, and it can be easily adapted to support other document stores.

  * **Access control** &ndash; (Under development) Racer will have hooks for access control to protect documents from malicious reads and writes.

  * **Solr queries** &ndash; (Under development) A Solr adapter will support updating Solr indices as data change and queries for realtime updated search results.


## Future features

  * **Browser local storage** &ndash; Pending changes and offline model data will also sync to HTML5 localStorage for persistent offline usage.

  * **Validation** &ndash; An implementation of shared and non-shared schema-based validation is planned.


## Installation

Racer requires [Node v0.10](http://nodejs.org/). You will also need to have a [MongoDB](http://docs.mongodb.org/manual/installation/) and a [Redis](http://redis.io/download) server running on your machine. The examples will connect via the default configurations.

```
$ npm install racer
```

## Tests

Run the tests with

```
$ npm test
```

## Usage

Racer can be used independently as shown in the examples, but Racer and Derby are designed to work especially well together. Racer can also be used along with other MVC frameworks, such as Angular.

For now, Racer is mostly documented along with Derby. See the Derby [model docs](http://derbyjs.com/docs/derby-0.6/models).

### MIT License
Copyright (c) 2011 by Brian Noguchi and Nate Smith

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
