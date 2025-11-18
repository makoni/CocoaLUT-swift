@_exported import Foundation
import Testing

// MARK: - Common Helpers

private func makeLocation(file: StaticString, line: UInt) -> SourceLocation {
    let fileString = String(describing: file)
    let path: String
    if fileString.hasPrefix("/") {
        path = fileString
    } else {
        let cwd = FileManager.default.currentDirectoryPath
        path = cwd + "/" + fileString
    }

    let resolvedLine = max(Int(line), 1)
    return SourceLocation(fileID: fileString, filePath: path, line: resolvedLine, column: 1)
}

private func makeComment(_ message: String) -> Comment? {
    let value = message
    return value.isEmpty ? nil : Comment(rawValue: value)
}

// MARK: - Failures

func XCTFail(
    _ message: @autoclosure () -> String = "",
    file: StaticString = #fileID,
    line: UInt = #line
) {
    Issue.record(makeComment(message()) ?? Comment("Failure"), sourceLocation: makeLocation(file: file, line: line))
}

// MARK: - Assertions

func XCTAssertTrue(
    _ expression: @autoclosure () throws -> Bool,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #fileID,
    line: UInt = #line
) rethrows {
    let value = try expression()
    #expect(value, makeComment(message()), sourceLocation: makeLocation(file: file, line: line))
}

func XCTAssertFalse(
    _ expression: @autoclosure () throws -> Bool,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #fileID,
    line: UInt = #line
) rethrows {
    let value = try expression()
    #expect(!value, makeComment(message()), sourceLocation: makeLocation(file: file, line: line))
}

func XCTAssertNil(
    _ expression: @autoclosure () throws -> Any?,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #fileID,
    line: UInt = #line
) rethrows {
    let value = try expression()
    #expect(value == nil, makeComment(message()), sourceLocation: makeLocation(file: file, line: line))
}

func XCTAssertNotNil(
    _ expression: @autoclosure () throws -> Any?,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #fileID,
    line: UInt = #line
) rethrows {
    let value = try expression()
    #expect(value != nil, makeComment(message()), sourceLocation: makeLocation(file: file, line: line))
}

func XCTAssertEqual<T: Equatable>(
    _ expression1: @autoclosure () throws -> T,
    _ expression2: @autoclosure () throws -> T,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #fileID,
    line: UInt = #line
) rethrows {
    let lhs = try expression1()
    let rhs = try expression2()
    #expect(lhs == rhs, makeComment(message()), sourceLocation: makeLocation(file: file, line: line))
}

func XCTAssertEqual<T: FloatingPoint>(
    _ expression1: @autoclosure () throws -> T,
    _ expression2: @autoclosure () throws -> T,
    accuracy: T,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #fileID,
    line: UInt = #line
) rethrows {
    let lhs = try expression1()
    let rhs = try expression2()
    #expect(abs(lhs - rhs) <= accuracy, makeComment(message()), sourceLocation: makeLocation(file: file, line: line))
}

func XCTAssertNotEqual<T: Equatable>(
    _ expression1: @autoclosure () throws -> T,
    _ expression2: @autoclosure () throws -> T,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #fileID,
    line: UInt = #line
) rethrows {
    let lhs = try expression1()
    let rhs = try expression2()
    #expect(lhs != rhs, makeComment(message()), sourceLocation: makeLocation(file: file, line: line))
}

func XCTAssertGreaterThan<T: Comparable>(
    _ expression1: @autoclosure () throws -> T,
    _ expression2: @autoclosure () throws -> T,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #fileID,
    line: UInt = #line
) rethrows {
    let lhs = try expression1()
    let rhs = try expression2()
    #expect(lhs > rhs, makeComment(message()), sourceLocation: makeLocation(file: file, line: line))
}

func XCTAssertGreaterThanOrEqual<T: Comparable>(
    _ expression1: @autoclosure () throws -> T,
    _ expression2: @autoclosure () throws -> T,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #fileID,
    line: UInt = #line
) rethrows {
    let lhs = try expression1()
    let rhs = try expression2()
    #expect(lhs >= rhs, makeComment(message()), sourceLocation: makeLocation(file: file, line: line))
}

func XCTAssertLessThan<T: Comparable>(
    _ expression1: @autoclosure () throws -> T,
    _ expression2: @autoclosure () throws -> T,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #fileID,
    line: UInt = #line
) rethrows {
    let lhs = try expression1()
    let rhs = try expression2()
    #expect(lhs < rhs, makeComment(message()), sourceLocation: makeLocation(file: file, line: line))
}

func XCTAssertLessThanOrEqual<T: Comparable>(
    _ expression1: @autoclosure () throws -> T,
    _ expression2: @autoclosure () throws -> T,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #fileID,
    line: UInt = #line
) rethrows {
    let lhs = try expression1()
    let rhs = try expression2()
    #expect(lhs <= rhs, makeComment(message()), sourceLocation: makeLocation(file: file, line: line))
}

func XCTAssertThrowsError<T>(
    _ expression: @autoclosure () throws -> T,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #fileID,
    line: UInt = #line,
    _ errorHandler: (Error) -> Void = { _ in }
) {
    do {
        _ = try expression()
        XCTFail(message(), file: file, line: line)
    } catch {
        errorHandler(error)
    }
}

// MARK: - Unwrap

enum XCTUnwrapError: Error {
    case foundNil
}

// MARK: - XCTContext Compatibility

enum XCTContext {
    struct Activity {}

    @discardableResult
    static func runActivity<Result>(named name: String, block: (Activity) throws -> Result) rethrows -> Result {
        try block(Activity())
    }
}

@discardableResult
func XCTUnwrap<T>(
    _ expression: @autoclosure () throws -> T?,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #fileID,
    line: UInt = #line
) throws -> T {
    guard let value = try expression() else {
        let resolvedMessage = message()
        let failureMessage = resolvedMessage.isEmpty ? "Unexpected nil value" : resolvedMessage
        XCTFail(failureMessage, file: file, line: line)
        throw XCTUnwrapError.foundNil
    }
    return value
}
