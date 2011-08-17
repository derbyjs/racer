# Racer

Racer is an **experimental** library for Node.js that provides realtime synchronization of an application model.

On the server, Racer exposes `racer.store`, which manages data updates. The store interacts with a Software Transactional Memory (STM) that prevents conflicting changes from being accepted. The store has accessor and mutator methods, which create transactions that get submitted to the STM. These methods are asynchronous, and using them is similar to getting or setting data from a database.

The store also creates models via `store.subscribe`. Models maintain their own copy of a subset of the global state. These models perform operations independently from the store and each other, and they automatically synchronize their state with the store.

Models provide a synchronous interface, so using them is more like interacting with regular objects. After a value is set on a model, the model will immediately reflect the new value, even though the operation is still being sent to the server in the background. This optimistic approach provides immediate interaction for the user and allows Racer to work offline. Operations may ultimately fail if they conflict with other changes. Therefore, model methods have callbacks for handling errors. Models also emit events when their contents are updated, which developers can use to update the application view in realtime.

## Disclaimer

Racer is not ready for use, so **please do not report bugs or contribute pull requests yet**. Lots of the code is being actively rewritten, and the API is likely to change substantially.

If you have feedback, ideas, or suggestions, feel free to leave them on the [wiki](https://github.com/codeparty/racer/wiki). However, your suggestions and issues are unlikely to be addressed until after the initially planned work is completed. If you are interested in contributing, please reach out to [Brian](https://github.com/bnoguchi) and [Nate](https://github.com/nateps) first.

## Demos

There are currently two demos, which are included under the examples directory.

### Letters

http://racerjs.com/letters/lobby

The letters game allows for multiple players to drag around refrigerator magnet style letters in realtime. It supports multiple rooms, where the room name is the URL path.

Letters demonstrates how applications can use Racer to provide application specific conflict resolution. Try using Firefox's Work Offline feature to move some letters while you move the same letters in another browser that is still connected. Then, disable offline mode and reconnect. Note that conflicting moves are shown along with the new moves that were successfully made. It is then possible to accept or override the moves that were already made.

### Todos

http://racerjs.com/todos/racer

Todos is a classic todo list demo that demonstrates the use of Racer's array methods in a more realistic application. The application code does not handle conflicts, so conflicting changes simply fail to be applied.

## Features

  * **Realtime updates** &ndash; Model methods automatically propagate changes among browser clients and Node servers in realtime. Clients may subscribe to a limited set of information relevant to the current session.

  * **Conflict resolution** &ndash; When multiple clients attempt to change data in an inconsistent manner, Racer updates the models and notifies clients of conflicts. Model methods have callbacks that allow for application specific behavior.

  * **Immediate interaction** &ndash; Model methods appear to take effect immediately. Meanwhile, Racer sends updates to the server and checks for conflicts. If the updates are successful, they are stored and broadcast to other clients.

  * **Offline** &ndash; Since model methods are applied immediately, clients continue to work offline. Any changes to the local client or the global state automatically sync upon reconnecting.

  * **Unified server and client interface** &ndash; The same model interface can be used on the server for initial page rendering and on the client for synchronization and user interaction.

## Future features

  * **Persistent storage** &ndash; Racer will optionally provide automatic storage of data in popular NoSQL document stores and MySQL. Racer will also support extension to support other persistent storage solutions.

  * **Browser local storage** &ndash; Browser models will also sync to HTML5 localStorage for persistent offline usage.

  * **Connect middleware** &ndash; Connect middleware will provide support for easy integration with Express and Connect sessions.

  * **Validation and access control** &ndash; An implementation of schema-based validation and authorization is planned.

  * **Alternative realtime strategies** &ndash; In addition to STM, Racer may provide Operational Transformation (OT) and Diff-Match-Patch algorithms. Developers would be able to mix and match strategies as appropriate for their object models.

## Installation

The heart of Racer's conflict detection is an STM built on top of Redis. It uses Redis Lua scripting, which is not part of the current stable Redis release, but [should be added](http://antirez.com/post/everything-about-redis-24) in the fall with Redis 2.6. For now, you can install the [Redis 2.2-scripting branch](https://github.com/antirez/redis/tree/2.2-scripting).

After Redis with scripting support is installed, simply add "racer" to your package.json dependencies and run

```
$ npm install
```

or install Racer for use in multiple node projects with

```
$ npm install racer -g
```

## Tests

The tests will flush Redis and MongoDB databases available via the default configurations, so don't run them in a production environment. The full suite currently requires a running Redis and MongoDB server to complete. Run the tests with

```
$ make test
```

## Usage

Honestly, it is not recommended that you use Racer just yet. If you are super excited to play around with it, check out the source code in the examples directory. The API will be documented here once the project becomes more stable.

