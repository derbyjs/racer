# Racer

Racer is a realtime model synchronization engine for Node.js. It enables mutliple users to interact with the same data objects via sophisticated conflict detection and resolution algorithms. At the same time, it provides a simple object accessor and event interface for writing application logic.

[![Build
Status](https://secure.travis-ci.org/codeparty/racer.png)](http://travis-ci.org/codeparty/racer)

## Disclaimer

Racer is alpha software. While it should work well enough for prototyping and weekend projects, it is still undergoing major development. APIs are subject to change.

If you are interested in contributing, please reach out to [Brian](https://github.com/bnoguchi) and [Nate](https://github.com/nateps).

## Demos

There are currently two demos, which are included under the examples directory.

### Letters

http://letters.racerjs.com/lobby

The letters game allows for multiple players to drag around refrigerator magnet style letters in realtime. It supports multiple rooms, where the room name is the URL path.

Letters demonstrates how applications can use Racer to provide application specific conflict resolution. Try using Firefox's Work Offline feature to move some letters while you move the same letters in another browser that is still connected. Then, disable offline mode and reconnect. Note that conflicting moves are shown along with the new moves that were successfully made. It is then possible to accept or override the moves that were already made.

### Todos

http://todos.racerjs.com/racer

Todos is a classic todo list demo that demonstrates the use of Racer's array methods in a more realistic application. The application code does not handle conflicts, so conflicting changes simply fail to be applied.

### Pad

http://pad.racerjs.com/racer

A bare-bones realtime, collaborative text editor. Demonstrates use of Racer's text OT methods.

## Features

  * **Realtime updates** &ndash; Model methods automatically propagate changes among browser clients and Node servers in realtime. Clients may subscribe to a limited set of information relevant to the current session.

  * **Conflict resolution** &ndash; When multiple clients attempt to change data in an inconsistent manner, Racer updates the models and notifies clients of conflicts. Model methods have callbacks that allow for application specific behavior.

  * **Immediate interaction** &ndash; Model methods appear to take effect immediately. Meanwhile, Racer sends updates to the server and checks for conflicts. If the updates are successful, they are stored and broadcast to other clients.

  * **Offline** &ndash; Since model methods are applied immediately, clients continue to work offline. Any changes to the local client or the global state automatically sync upon reconnecting.

  * **Session middleware** &ndash; Connect middleware provides support for easy integration with Express and Connect sessions.

  * **Unified server and client interface** &ndash; The same model interface can be used on the server for initial page rendering and on the client for synchronization and user interaction.

  * **Persistent storage** &ndash; Racer provides automatic storage of data via
    the [racer-db-mongo plugin](https://github.com/codeparty/racer-db-mongo). Racer
    provides a straightforward API for implementing similar plugins for
    document stores such as Riak, Couchdb, Postgres HSTORE, and other databases.

  * **Access control** &ndash; Racer provides a declarative access control API
    to protect your queries and documents from malicious reads and writes.

## Future features

  * **Browser local storage** &ndash; Browser models will also sync to HTML5 localStorage for persistent offline usage.

  * **Validation** &ndash; An implementation of shared and non-shared schema-based validation is planned.

  * **More realtime strategies** &ndash; Currently, racer provides basic Software Transactional Memory (STM) and text Operational Transform (OT) methods. In the future it will receive a more robust STM, OT of JSON objects, and potentially other strategies like Diff-Match-Patch.

## Installation

Install Racer with

```
$ npm install racer
```

In addition, racer requires Redis with scripting support for storing a journal of transactions. See the Derby [installation instructions](http://derbyjs.com/#getting_started).

## Tests

The tests will flush Redis and MongoDB databases available via the default configurations, so don't run them in a production environment. The full suite currently requires a running Redis and MongoDB server to complete. Run the tests with

```
$ make test
```

## Usage

For now, Racer is mostly documented along with Derby, an MVC framework that includes Racer. See the Derby [model docs](http://derbyjs.com/#models). Racer can be used independently, but Racer and Derby are designed to work well together.

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
