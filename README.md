# MLIR Utils

## Building
To build, run
```sh
swift build -c release
```
To show the path of the generated binary, run
```sh
swift build -c release --show-bin-path
```

## Subcommands

### Create Dialect
Create a new dialect.

#### Example
To create a dialect called `MyDialect` in the directory `~/Desktop`
and the `llvm-project` source is in `${LLVM_SOURCE_DIR}`, run

```sh
mlir-utils create-dialect MyDialect ${LLVM_SOURCE_DIR} ~/Desktop
```

### Rename Dialect
Rename a dialect.

#### Example
To rename the `Standalone` dialect in `~/Desktop/standalone` to `MyDialect`, run
```sh
mlir-utils rename-dialect Standalone MyDialect ~/Desktop/standalone
```
