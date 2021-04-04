# Sentinel

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

After that, when you change any file under `lib` and `test` directory will automatically run a corresponding unit test if available or all tests.

If you wish to also run integration tests, include `-i` option.

```sh
$ sentinel -i
```

[Jest]: https://jestjs.io
[Guard]: https://github.com/guard/guard