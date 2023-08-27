# Design

## Symbol Resolution

Same as `protoc`. As far as I can tell, it works as follows:
- Obtain include paths
- Imports are rooted at the include paths
- Symbols in the same package do not need a package specifier
- Symbols in different packages do
- A file with no package is in the same package as other files with no package
- `.[symbol]` are always resolved from the top down, not even considering the same package rule
- See https://protobuf.com/docs/language-spec#relative-references for a more comprehensive overview
