# Sentinel

[![build](https://github.com/asartalo/sentinel/actions/workflows/build.yml/badge.svg)](https://github.com/asartalo/sentinel/actions/workflows/build.yml) [![Coverage Status](https://coveralls.io/repos/github/asartalo/sentinel/badge.svg?branch=main)](https://coveralls.io/github/asartalo/sentinel?branch=main) [![Pub](https://img.shields.io/pub/v/sentinel.svg)](https://pub.dev/packages/sentinel)

A Dart and Flutter project automatic test runner to run tests automatically as files change. Inspired by [Jest][Jest] and Ruby's [Guard][Guard].


## Installation

Install sentinel globally so it won't cause conflicts with your dependencies.

```sh
$ pub global activate sentinel
```

## Usage

On your Dart or Flutter project's root directory run:

```sh
$ sentinel
```

After that, when you change any file under `lib` and `test` directory, sentinel will automatically run a corresponding unit test if available or all tests.

### Running Integration Tests

**Warning:** this feature is experimental.

If you wish to also run integration tests like in a flutter project, use the `-i` option.

```sh
$ sentinel -i
```

[Jest]: https://jestjs.io
[Guard]: https://github.com/guard/guard