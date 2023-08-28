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
                },
            };
        };
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
            },
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
        };

        pub const Kind = enum(i64) {
            pub const protobuf_metadata = .{
                .syntax = .proto3,
            };

            Formal = 0,
            Informal = 1,
        };
    };
};
