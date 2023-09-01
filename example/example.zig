const std = @import("std");

pub const hello = struct {
    pub const pog = struct {
        pub const Variant = enum(i64) {
            pub const protobuf_metadata = .{
                .syntax = .proto3,
            };

            Cool = 0,
            Awesome = 1,
        };

        pub const Swag = struct {
            pub const protobuf_metadata = .{
                .syntax = .proto3,
                .field_numbers = .{
                    .variant = 1,
                    .reverse = 2,
                    .again = 3,
                },
            };

            variant: hello.pog.Variant = .{},
            reverse: hello.Reverse = .{},
            again: pogpog.ReverseAgain = .{},
        };
    };

    pub const Cool = enum(i64) {
        pub const protobuf_metadata = .{
            .syntax = .proto3,
        };

        None = 0,
    };

    pub const Greeting = struct {
        pub const protobuf_metadata = .{
            .syntax = .proto3,
            .field_numbers = .{
                .kind = 1,
                .recipient = 2,
                .anotherKind = 3,
                .anotherKind2 = 4,
                .anotherKind3 = 5,
                .cool = 6,
            },
        };

        pub const Kind = enum(i64) {
            pub const protobuf_metadata = .{
                .syntax = .proto3,
            };

            Formal = 0,
            Informal = 1,
        };

        pub const Recipient = struct {
            pub const protobuf_metadata = .{
                .syntax = .proto3,
                .field_numbers = .{
                    .name = 1,
                    .coolness_percent = 2,
                    .swag = 3,
                },
            };

            name: []const u8 = "",
            coolness_percent: i64 = 0,
            swag: hello.pog.Swag = .{},
        };

        kind: hello.Greeting.Kind = .{},
        recipient: hello.Greeting.Recipient = .{},
        anotherKind: hello.Greeting.Kind = .{},
        anotherKind2: hello.Greeting.Kind = .{},
        anotherKind3: hello.Greeting.Kind = .{},
        cool: hello.Cool = .{},
    };

    pub const Reverse = enum(i64) {
        pub const protobuf_metadata = .{
            .syntax = .proto3,
        };

        Poggers = 0,
    };
};

pub const pogpog = struct {
    pub const ReverseAgain = enum(i64) {
        pub const protobuf_metadata = .{
            .syntax = .proto3,
        };

        Amongus = 0,
    };
};
