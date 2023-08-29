const std = @import("std");

pub const opentelemetry = struct {
    pub const proto = struct {
        pub const metrics = struct {
            pub const v1 = struct {
                pub const MetricsData = struct {
                    pub const protobuf_metadata = .{
                        .syntax = .proto3,
                        .field_numbers = .{
                            .resource_metrics = 1,
                        },
                    };

                    resource_metrics: std.ArrayListUnmanaged(ResourceMetrics) = .{},
                };

                pub const ResourceMetrics = struct {
                    pub const protobuf_metadata = .{
                        .syntax = .proto3,
                        .field_numbers = .{
                            .resource = 1,
                            .scope_metrics = 2,
                            .schema_url = 3,
                        },
                    };

                    resource: opentelemetry.proto.resource.v1.Resource = .{},
                    scope_metrics: std.ArrayListUnmanaged(ScopeMetrics) = .{},
                    schema_url: []const u8 = "",
                };

                pub const ScopeMetrics = struct {
                    pub const protobuf_metadata = .{
                        .syntax = .proto3,
                        .field_numbers = .{
                            .scope = 1,
                            .metrics = 2,
                            .schema_url = 3,
                        },
                    };

                    scope: opentelemetry.proto.common.v1.InstrumentationScope = .{},
                    metrics: std.ArrayListUnmanaged(Metric) = .{},
                    schema_url: []const u8 = "",
                };

                pub const Metric = struct {
                    pub const protobuf_metadata = .{
                        .syntax = .proto3,
                        .field_numbers = .{
                            .name = 1,
                            .description = 2,
                            .unit = 3,
                        },
                    };

                    name: []const u8 = "",
                    description: []const u8 = "",
                    unit: []const u8 = "",
                };

                pub const Gauge = struct {
                    pub const protobuf_metadata = .{
                        .syntax = .proto3,
                        .field_numbers = .{
                            .data_points = 1,
                        },
                    };

                    data_points: std.ArrayListUnmanaged(NumberDataPoint) = .{},
                };

                pub const Sum = struct {
                    pub const protobuf_metadata = .{
                        .syntax = .proto3,
                        .field_numbers = .{
                            .data_points = 1,
                            .aggregation_temporality = 2,
                            .is_monotonic = 3,
                        },
                    };

                    data_points: std.ArrayListUnmanaged(NumberDataPoint) = .{},
                    aggregation_temporality: AggregationTemporality = .{},
                    is_monotonic: bool = false,
                };

                pub const Histogram = struct {
                    pub const protobuf_metadata = .{
                        .syntax = .proto3,
                        .field_numbers = .{
                            .data_points = 1,
                            .aggregation_temporality = 2,
                        },
                    };

                    data_points: std.ArrayListUnmanaged(HistogramDataPoint) = .{},
                    aggregation_temporality: AggregationTemporality = .{},
                };

                pub const ExponentialHistogram = struct {
                    pub const protobuf_metadata = .{
                        .syntax = .proto3,
                        .field_numbers = .{
                            .data_points = 1,
                            .aggregation_temporality = 2,
                        },
                    };

                    data_points: std.ArrayListUnmanaged(ExponentialHistogramDataPoint) = .{},
                    aggregation_temporality: AggregationTemporality = .{},
                };

                pub const Summary = struct {
                    pub const protobuf_metadata = .{
                        .syntax = .proto3,
                        .field_numbers = .{
                            .data_points = 1,
                        },
                    };

                    data_points: std.ArrayListUnmanaged(SummaryDataPoint) = .{},
                };

                pub const AggregationTemporality = enum(i64) {
                    pub const protobuf_metadata = .{
                        .syntax = .proto3,
                    };

                    AGGREGATION_TEMPORALITY_UNSPECIFIED = 0,
                    AGGREGATION_TEMPORALITY_DELTA = 1,
                    AGGREGATION_TEMPORALITY_CUMULATIVE = 2,
                };

                pub const DataPointFlags = enum(i64) {
                    pub const protobuf_metadata = .{
                        .syntax = .proto3,
                    };

                    DATA_POINT_FLAGS_DO_NOT_USE = 0,
                    DATA_POINT_FLAGS_NO_RECORDED_VALUE_MASK = 1,
                };

                pub const NumberDataPoint = struct {
                    pub const protobuf_metadata = .{
                        .syntax = .proto3,
                        .field_numbers = .{
                            .attributes = 7,
                            .start_time_unix_nano = 2,
                            .time_unix_nano = 3,
                            .exemplars = 5,
                            .flags = 8,
                        },
                    };

                    attributes: std.ArrayListUnmanaged(opentelemetry.proto.common.v1.KeyValue) = .{},
                    start_time_unix_nano: u64 = 0,
                    time_unix_nano: u64 = 0,
                    exemplars: std.ArrayListUnmanaged(Exemplar) = .{},
                    flags: u32 = 0,
                };

                pub const HistogramDataPoint = struct {
                    pub const protobuf_metadata = .{
                        .syntax = .proto3,
                        .field_numbers = .{
                            .attributes = 9,
                            .start_time_unix_nano = 2,
                            .time_unix_nano = 3,
                            .count = 4,
                            .sum = 5,
                            .bucket_counts = 6,
                            .explicit_bounds = 7,
                            .exemplars = 8,
                            .flags = 10,
                            .min = 11,
                            .max = 12,
                        },
                    };

                    attributes: std.ArrayListUnmanaged(opentelemetry.proto.common.v1.KeyValue) = .{},
                    start_time_unix_nano: u64 = 0,
                    time_unix_nano: u64 = 0,
                    count: u64 = 0,
                    sum: ?f64 = null,
                    bucket_counts: std.ArrayListUnmanaged(u64) = .{},
                    explicit_bounds: std.ArrayListUnmanaged(f64) = .{},
                    exemplars: std.ArrayListUnmanaged(Exemplar) = .{},
                    flags: u32 = 0,
                    min: ?f64 = null,
                    max: ?f64 = null,
                };

                pub const ExponentialHistogramDataPoint = struct {
                    pub const protobuf_metadata = .{
                        .syntax = .proto3,
                        .field_numbers = .{
                            .attributes = 1,
                            .start_time_unix_nano = 2,
                            .time_unix_nano = 3,
                            .count = 4,
                            .sum = 5,
                            .scale = 6,
                            .zero_count = 7,
                            .positive = 8,
                            .negative = 9,
                            .flags = 10,
                            .exemplars = 11,
                            .min = 12,
                            .max = 13,
                            .zero_threshold = 14,
                        },
                    };

                    pub const Buckets = struct {
                        pub const protobuf_metadata = .{
                            .syntax = .proto3,
                            .field_numbers = .{
                                .offset = 1,
                                .bucket_counts = 2,
                            },
                        };

                        offset: i32 = 0,
                        bucket_counts: std.ArrayListUnmanaged(u64) = .{},
                    };

                    attributes: std.ArrayListUnmanaged(opentelemetry.proto.common.v1.KeyValue) = .{},
                    start_time_unix_nano: u64 = 0,
                    time_unix_nano: u64 = 0,
                    count: u64 = 0,
                    sum: ?f64 = null,
                    scale: i32 = 0,
                    zero_count: u64 = 0,
                    positive: Buckets = .{},
                    negative: Buckets = .{},
                    flags: u32 = 0,
                    exemplars: std.ArrayListUnmanaged(Exemplar) = .{},
                    min: ?f64 = null,
                    max: ?f64 = null,
                    zero_threshold: f64 = 0,
                };

                pub const SummaryDataPoint = struct {
                    pub const protobuf_metadata = .{
                        .syntax = .proto3,
                        .field_numbers = .{
                            .attributes = 7,
                            .start_time_unix_nano = 2,
                            .time_unix_nano = 3,
                            .count = 4,
                            .sum = 5,
                            .quantile_values = 6,
                            .flags = 8,
                        },
                    };

                    pub const ValueAtQuantile = struct {
                        pub const protobuf_metadata = .{
                            .syntax = .proto3,
                            .field_numbers = .{
                                .quantile = 1,
                                .value = 2,
                            },
                        };

                        quantile: f64 = 0,
                        value: f64 = 0,
                    };

                    attributes: std.ArrayListUnmanaged(opentelemetry.proto.common.v1.KeyValue) = .{},
                    start_time_unix_nano: u64 = 0,
                    time_unix_nano: u64 = 0,
                    count: u64 = 0,
                    sum: f64 = 0,
                    quantile_values: std.ArrayListUnmanaged(ValueAtQuantile) = .{},
                    flags: u32 = 0,
                };

                pub const Exemplar = struct {
                    pub const protobuf_metadata = .{
                        .syntax = .proto3,
                        .field_numbers = .{
                            .filtered_attributes = 7,
                            .time_unix_nano = 2,
                            .span_id = 4,
                            .trace_id = 5,
                        },
                    };

                    filtered_attributes: std.ArrayListUnmanaged(opentelemetry.proto.common.v1.KeyValue) = .{},
                    time_unix_nano: u64 = 0,
                    span_id: []const u8 = "",
                    trace_id: []const u8 = "",
                };
            };
        };

        pub const trace = struct {
            pub const v1 = struct {
                pub const TracesData = struct {
                    pub const protobuf_metadata = .{
                        .syntax = .proto3,
                        .field_numbers = .{
                            .resource_spans = 1,
                        },
                    };

                    resource_spans: std.ArrayListUnmanaged(ResourceSpans) = .{},
                };

                pub const ResourceSpans = struct {
                    pub const protobuf_metadata = .{
                        .syntax = .proto3,
                        .field_numbers = .{
                            .resource = 1,
                            .scope_spans = 2,
                            .schema_url = 3,
                        },
                    };

                    resource: opentelemetry.proto.resource.v1.Resource = .{},
                    scope_spans: std.ArrayListUnmanaged(ScopeSpans) = .{},
                    schema_url: []const u8 = "",
                };

                pub const ScopeSpans = struct {
                    pub const protobuf_metadata = .{
                        .syntax = .proto3,
                        .field_numbers = .{
                            .scope = 1,
                            .spans = 2,
                            .schema_url = 3,
                        },
                    };

                    scope: opentelemetry.proto.common.v1.InstrumentationScope = .{},
                    spans: std.ArrayListUnmanaged(Span) = .{},
                    schema_url: []const u8 = "",
                };

                pub const Span = struct {
                    pub const protobuf_metadata = .{
                        .syntax = .proto3,
                        .field_numbers = .{
                            .trace_id = 1,
                            .span_id = 2,
                            .trace_state = 3,
                            .parent_span_id = 4,
                            .name = 5,
                            .kind = 6,
                            .start_time_unix_nano = 7,
                            .end_time_unix_nano = 8,
                            .attributes = 9,
                            .dropped_attributes_count = 10,
                            .events = 11,
                            .dropped_events_count = 12,
                            .links = 13,
                            .dropped_links_count = 14,
                            .status = 15,
                        },
                    };

                    pub const SpanKind = enum(i64) {
                        pub const protobuf_metadata = .{
                            .syntax = .proto3,
                        };

                        SPAN_KIND_UNSPECIFIED = 0,
                        SPAN_KIND_INTERNAL = 1,
                        SPAN_KIND_SERVER = 2,
                        SPAN_KIND_CLIENT = 3,
                        SPAN_KIND_PRODUCER = 4,
                        SPAN_KIND_CONSUMER = 5,
                    };

                    pub const Event = struct {
                        pub const protobuf_metadata = .{
                            .syntax = .proto3,
                            .field_numbers = .{
                                .time_unix_nano = 1,
                                .name = 2,
                                .attributes = 3,
                                .dropped_attributes_count = 4,
                            },
                        };

                        time_unix_nano: u64 = 0,
                        name: []const u8 = "",
                        attributes: std.ArrayListUnmanaged(opentelemetry.proto.common.v1.KeyValue) = .{},
                        dropped_attributes_count: u32 = 0,
                    };

                    pub const Link = struct {
                        pub const protobuf_metadata = .{
                            .syntax = .proto3,
                            .field_numbers = .{
                                .trace_id = 1,
                                .span_id = 2,
                                .trace_state = 3,
                                .attributes = 4,
                                .dropped_attributes_count = 5,
                            },
                        };

                        trace_id: []const u8 = "",
                        span_id: []const u8 = "",
                        trace_state: []const u8 = "",
                        attributes: std.ArrayListUnmanaged(opentelemetry.proto.common.v1.KeyValue) = .{},
                        dropped_attributes_count: u32 = 0,
                    };

                    trace_id: []const u8 = "",
                    span_id: []const u8 = "",
                    trace_state: []const u8 = "",
                    parent_span_id: []const u8 = "",
                    name: []const u8 = "",
                    kind: SpanKind = .{},
                    start_time_unix_nano: u64 = 0,
                    end_time_unix_nano: u64 = 0,
                    attributes: std.ArrayListUnmanaged(opentelemetry.proto.common.v1.KeyValue) = .{},
                    dropped_attributes_count: u32 = 0,
                    events: std.ArrayListUnmanaged(Event) = .{},
                    dropped_events_count: u32 = 0,
                    links: std.ArrayListUnmanaged(Link) = .{},
                    dropped_links_count: u32 = 0,
                    status: Status = .{},
                };

                pub const Status = struct {
                    pub const protobuf_metadata = .{
                        .syntax = .proto3,
                        .field_numbers = .{
                            .message = 2,
                            .code = 3,
                        },
                    };

                    pub const StatusCode = enum(i64) {
                        pub const protobuf_metadata = .{
                            .syntax = .proto3,
                        };

                        STATUS_CODE_UNSET = 0,
                        STATUS_CODE_OK = 1,
                        STATUS_CODE_ERROR = 2,
                    };

                    message: []const u8 = "",
                    code: StatusCode = .{},
                };
            };
        };

        pub const collector = struct {
            pub const metrics = struct {
                pub const v1 = struct {
                    pub const ExportMetricsServiceRequest = struct {
                        pub const protobuf_metadata = .{
                            .syntax = .proto3,
                            .field_numbers = .{
                                .resource_metrics = 1,
                            },
                        };

                        resource_metrics: std.ArrayListUnmanaged(opentelemetry.proto.metrics.v1.ResourceMetrics) = .{},
                    };

                    pub const ExportMetricsServiceResponse = struct {
                        pub const protobuf_metadata = .{
                            .syntax = .proto3,
                            .field_numbers = .{
                                .partial_success = 1,
                            },
                        };

                        partial_success: ExportMetricsPartialSuccess = .{},
                    };

                    pub const ExportMetricsPartialSuccess = struct {
                        pub const protobuf_metadata = .{
                            .syntax = .proto3,
                            .field_numbers = .{
                                .rejected_data_points = 1,
                                .error_message = 2,
                            },
                        };

                        rejected_data_points: i64 = 0,
                        error_message: []const u8 = "",
                    };
                };
            };

            pub const trace = struct {
                pub const v1 = struct {
                    pub const ExportTraceServiceRequest = struct {
                        pub const protobuf_metadata = .{
                            .syntax = .proto3,
                            .field_numbers = .{
                                .resource_spans = 1,
                            },
                        };

                        resource_spans: std.ArrayListUnmanaged(opentelemetry.proto.trace.v1.ResourceSpans) = .{},
                    };

                    pub const ExportTraceServiceResponse = struct {
                        pub const protobuf_metadata = .{
                            .syntax = .proto3,
                            .field_numbers = .{
                                .partial_success = 1,
                            },
                        };

                        partial_success: ExportTracePartialSuccess = .{},
                    };

                    pub const ExportTracePartialSuccess = struct {
                        pub const protobuf_metadata = .{
                            .syntax = .proto3,
                            .field_numbers = .{
                                .rejected_spans = 1,
                                .error_message = 2,
                            },
                        };

                        rejected_spans: i64 = 0,
                        error_message: []const u8 = "",
                    };
                };
            };

            pub const logs = struct {
                pub const v1 = struct {
                    pub const ExportLogsServiceRequest = struct {
                        pub const protobuf_metadata = .{
                            .syntax = .proto3,
                            .field_numbers = .{
                                .resource_logs = 1,
                            },
                        };

                        resource_logs: std.ArrayListUnmanaged(opentelemetry.proto.logs.v1.ResourceLogs) = .{},
                    };

                    pub const ExportLogsServiceResponse = struct {
                        pub const protobuf_metadata = .{
                            .syntax = .proto3,
                            .field_numbers = .{
                                .partial_success = 1,
                            },
                        };

                        partial_success: ExportLogsPartialSuccess = .{},
                    };

                    pub const ExportLogsPartialSuccess = struct {
                        pub const protobuf_metadata = .{
                            .syntax = .proto3,
                            .field_numbers = .{
                                .rejected_log_records = 1,
                                .error_message = 2,
                            },
                        };

                        rejected_log_records: i64 = 0,
                        error_message: []const u8 = "",
                    };
                };
            };
        };

        pub const common = struct {
            pub const v1 = struct {
                pub const AnyValue = struct {
                    pub const protobuf_metadata = .{
                        .syntax = .proto3,
                        .field_numbers = .{},
                    };
                };

                pub const ArrayValue = struct {
                    pub const protobuf_metadata = .{
                        .syntax = .proto3,
                        .field_numbers = .{
                            .values = 1,
                        },
                    };

                    values: std.ArrayListUnmanaged(AnyValue) = .{},
                };

                pub const KeyValueList = struct {
                    pub const protobuf_metadata = .{
                        .syntax = .proto3,
                        .field_numbers = .{
                            .values = 1,
                        },
                    };

                    values: std.ArrayListUnmanaged(KeyValue) = .{},
                };

                pub const KeyValue = struct {
                    pub const protobuf_metadata = .{
                        .syntax = .proto3,
                        .field_numbers = .{
                            .key = 1,
                            .value = 2,
                        },
                    };

                    key: []const u8 = "",
                    value: AnyValue = .{},
                };

                pub const InstrumentationScope = struct {
                    pub const protobuf_metadata = .{
                        .syntax = .proto3,
                        .field_numbers = .{
                            .name = 1,
                            .version = 2,
                            .attributes = 3,
                            .dropped_attributes_count = 4,
                        },
                    };

                    name: []const u8 = "",
                    version: []const u8 = "",
                    attributes: std.ArrayListUnmanaged(KeyValue) = .{},
                    dropped_attributes_count: u32 = 0,
                };
            };
        };

        pub const logs = struct {
            pub const v1 = struct {
                pub const LogsData = struct {
                    pub const protobuf_metadata = .{
                        .syntax = .proto3,
                        .field_numbers = .{
                            .resource_logs = 1,
                        },
                    };

                    resource_logs: std.ArrayListUnmanaged(ResourceLogs) = .{},
                };

                pub const ResourceLogs = struct {
                    pub const protobuf_metadata = .{
                        .syntax = .proto3,
                        .field_numbers = .{
                            .resource = 1,
                            .scope_logs = 2,
                            .schema_url = 3,
                        },
                    };

                    resource: opentelemetry.proto.resource.v1.Resource = .{},
                    scope_logs: std.ArrayListUnmanaged(ScopeLogs) = .{},
                    schema_url: []const u8 = "",
                };

                pub const ScopeLogs = struct {
                    pub const protobuf_metadata = .{
                        .syntax = .proto3,
                        .field_numbers = .{
                            .scope = 1,
                            .log_records = 2,
                            .schema_url = 3,
                        },
                    };

                    scope: opentelemetry.proto.common.v1.InstrumentationScope = .{},
                    log_records: std.ArrayListUnmanaged(LogRecord) = .{},
                    schema_url: []const u8 = "",
                };

                pub const SeverityNumber = enum(i64) {
                    pub const protobuf_metadata = .{
                        .syntax = .proto3,
                    };

                    SEVERITY_NUMBER_UNSPECIFIED = 0,
                    SEVERITY_NUMBER_TRACE = 1,
                    SEVERITY_NUMBER_TRACE2 = 2,
                    SEVERITY_NUMBER_TRACE3 = 3,
                    SEVERITY_NUMBER_TRACE4 = 4,
                    SEVERITY_NUMBER_DEBUG = 5,
                    SEVERITY_NUMBER_DEBUG2 = 6,
                    SEVERITY_NUMBER_DEBUG3 = 7,
                    SEVERITY_NUMBER_DEBUG4 = 8,
                    SEVERITY_NUMBER_INFO = 9,
                    SEVERITY_NUMBER_INFO2 = 10,
                    SEVERITY_NUMBER_INFO3 = 11,
                    SEVERITY_NUMBER_INFO4 = 12,
                    SEVERITY_NUMBER_WARN = 13,
                    SEVERITY_NUMBER_WARN2 = 14,
                    SEVERITY_NUMBER_WARN3 = 15,
                    SEVERITY_NUMBER_WARN4 = 16,
                    SEVERITY_NUMBER_ERROR = 17,
                    SEVERITY_NUMBER_ERROR2 = 18,
                    SEVERITY_NUMBER_ERROR3 = 19,
                    SEVERITY_NUMBER_ERROR4 = 20,
                    SEVERITY_NUMBER_FATAL = 21,
                    SEVERITY_NUMBER_FATAL2 = 22,
                    SEVERITY_NUMBER_FATAL3 = 23,
                    SEVERITY_NUMBER_FATAL4 = 24,
                };

                pub const LogRecordFlags = enum(i64) {
                    pub const protobuf_metadata = .{
                        .syntax = .proto3,
                    };

                    LOG_RECORD_FLAGS_DO_NOT_USE = 0,
                    LOG_RECORD_FLAGS_TRACE_FLAGS_MASK = 255,
                };

                pub const LogRecord = struct {
                    pub const protobuf_metadata = .{
                        .syntax = .proto3,
                        .field_numbers = .{
                            .time_unix_nano = 1,
                            .observed_time_unix_nano = 11,
                            .severity_number = 2,
                            .severity_text = 3,
                            .body = 5,
                            .attributes = 6,
                            .dropped_attributes_count = 7,
                            .flags = 8,
                            .trace_id = 9,
                            .span_id = 10,
                        },
                    };

                    time_unix_nano: u64 = 0,
                    observed_time_unix_nano: u64 = 0,
                    severity_number: SeverityNumber = .{},
                    severity_text: []const u8 = "",
                    body: opentelemetry.proto.common.v1.AnyValue = .{},
                    attributes: std.ArrayListUnmanaged(opentelemetry.proto.common.v1.KeyValue) = .{},
                    dropped_attributes_count: u32 = 0,
                    flags: u32 = 0,
                    trace_id: []const u8 = "",
                    span_id: []const u8 = "",
                };
            };
        };

        pub const resource = struct {
            pub const v1 = struct {
                pub const Resource = struct {
                    pub const protobuf_metadata = .{
                        .syntax = .proto3,
                        .field_numbers = .{
                            .attributes = 1,
                            .dropped_attributes_count = 2,
                        },
                    };

                    attributes: std.ArrayListUnmanaged(opentelemetry.proto.common.v1.KeyValue) = .{},
                    dropped_attributes_count: u32 = 0,
                };
            };
        };
    };
};
