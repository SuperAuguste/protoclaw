# protoclaw

Fully self-contained Protobuf compiler for Zig.

<!-- omit in toc -->
## Table of Contents

- [protoclaw](#protoclaw)
  - [Usage](#usage)
    - [CLI](#cli)
    - [`build.zig` Integration](#buildzig-integration)
    - [Source File vs Include](#source-file-vs-include)
  - [References](#references)
  - [License](#license)

## Usage

### CLI

### `build.zig` Integration

You can use `protoclaw.GenerateStep` to generate Zig sources from Protobuf schemas in your `build.zig`. 
See [our `build.zig`](TODO) for an example. 

### Source File vs Include

In protoclaw, these are no different except that declarations from source files are public and declarations from included sources are private. You can override this behavior:

| Where | How |
| ----- | ---- |
| CLI | `protoclaw ... --visibility=all-public` |
| `build.zig` | `generate_step.visibility = .all_public;` |

## References

https://protobuf.com/docs/language-spec
https://protobuf.dev/reference/protobuf/proto2-spec/
https://protobuf.dev/reference/protobuf/proto3-spec/

## License

MIT except for all files in `include/`, which are licensed under Protobuf's BSD license, which is can be found at the start of those files or [here](https://github.com/protocolbuffers/protobuf/blob/main/LICENSE).
