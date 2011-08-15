# Racer

Racer is an **experimental** library for Node.js that provides realtime synchronization of an application model.

## Disclaimer

Racer is not ready for use, so **please do not report bugs or contribute pull requests yet**. Lots of the code is being actively rewritten, and the API is likely to change substantially.

If you have feedback, ideas, or suggestions, feel free to leave them on the [wiki](https://github.com/codeparty/racer/wiki). However, your suggestions and issues are unlikely to be addressed until after the initially planned work is completed. If you are interested in contributing, please reach out to [Brian](https://github.com/bnoguchi) and [Nate](https://github.com/nateps) first.

## Demos

Coming soon...

## Features

  * **Realtime updates** -- Model methods automatically propagate changes among browser clients and Node servers in realtime. Clients may subscribe to a limited set of information relevant to the current session.
  * **Immediate interaction** -- Model methods appear to take effect immediately. Meanwhile, Racer sends updates to the server and checks for conflicts. If the updates are successful, they are stored and broadcast to other clients.
  * **Conflict resolution** -- When multiple clients attempt to change data in an inconsistent manner, Racer updates the models and notifies clients of conflicts. Model methods have callbacks that allow for application specific behavior.
  * **Offline** -- Since model methods are applied immediately, clients continue to work offline. Any changes to the local client or the global state automatically sync upon reconnecting.
  * **Unified server and client interface** -- The same model interface can be used on the server for initial page rendering and on the client for synchronization and user interaction. Thus, it is possible to use rendering and business logic that interacts with the model on both the server and client.

## Future features

  * **Persistent storage** -- Racer will optionally provide automatic storage of data in popular NoSQL document stores and MySQL. Racer will also suppport extension to support other persistent storage solutions.
  * **Connect middleware** -- Connect middleware will provide support for easy integration with Express and Connect sessions
  * **Validation and access control** -- An implementation of schema-based validation and authorization is planned.

## Installation

## Tests

```
$ make test
```
