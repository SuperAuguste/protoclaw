# protoclaw

# this doesnt work yet, please do not use

Fully self-contained Protobuf compiler for Zig.

<!-- omit in toc -->
## Table of Contents

- [protoclaw](#protoclaw)
- [this doesnt work yet, please do not use](#this-doesnt-work-yet-please-do-not-use)
  - [Usage](#usage)
    - [CLI](#cli)
    - [`build.zig` Integration](#buildzig-integration)
  - [References](#references)
  - [License](#license)

## Usage

### CLI

### `build.zig` Integration

You can use `protoclaw.GenerateStep` to generate Zig sources from Protobuf schemas in your `build.zig`. 
See [our `build.zig`](TODO) for an example.

## References

https://protobuf.com/docs/language-spec
https://protobuf.dev/reference/protobuf/proto2-spec/
https://protobuf.dev/reference/protobuf/proto3-spec/

protoc .\example\hello.proto -Iexample --cpp_out=protoc-runs

## License

MIT except for all files in `include/`, which are licensed under Protobuf's BSD license, which is can be found at the start of those files or [here](https://github.com/protocolbuffers/protobuf/blob/main/LICENSE).
