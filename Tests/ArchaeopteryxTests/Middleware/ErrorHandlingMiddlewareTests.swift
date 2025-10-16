import XCTest
import Logging
import Hummingbird
@testable import Archaeopteryx

final class ErrorHandlingMiddlewareTests: XCTestCase {
    var logger: Logger!
    var middleware: ErrorHandlingMiddleware<BasicRequestContext>!

    override func setUp() async throws {
        try await super.setUp()
        logger = Logger(label: "test")
        logger.logLevel = .critical // Suppress logs during tests
        middleware = ErrorHandlingMiddleware(logger: logger)
    }

    override func tearDown() async throws {
        logger = nil
        middleware = nil
        try await super.tearDown()
    }

    // MARK: - Basic Tests

    func testErrorHandlingMiddleware_CanBeCreated() {
        XCTAssertNotNil(middleware)
    }

    // MARK: - HTTPError Tests

    func testHTTPError_BadRequest_HasCorrectProperties() {
        let error = Archaeopteryx.HTTPError.badRequest("Invalid parameter")

        XCTAssertEqual(error.code, "invalid_request")
        XCTAssertEqual(error.description, "Invalid parameter")
        XCTAssertEqual(error.status, .badRequest)
    }

    func testHTTPError_Unauthorized_HasCorrectProperties() {
        let error = Archaeopteryx.HTTPError.unauthorized()

        XCTAssertEqual(error.code, "unauthorized")
        XCTAssertEqual(error.description, "Authentication required")
        XCTAssertEqual(error.status, .unauthorized)
    }

    func testHTTPError_Forbidden_HasCorrectProperties() {
        let error = Archaeopteryx.HTTPError.forbidden()

        XCTAssertEqual(error.code, "forbidden")
        XCTAssertEqual(error.description, "Access denied")
        XCTAssertEqual(error.status, .forbidden)
    }

    func testHTTPError_NotFound_HasCorrectProperties() {
        let error = Archaeopteryx.HTTPError.notFound("User not found")

        XCTAssertEqual(error.code, "not_found")
        XCTAssertEqual(error.description, "User not found")
        XCTAssertEqual(error.status, .notFound)
    }

    func testHTTPError_UnprocessableEntity_HasCorrectProperties() {
        let error = Archaeopteryx.HTTPError.unprocessableEntity("Validation failed")

        XCTAssertEqual(error.code, "unprocessable_entity")
        XCTAssertEqual(error.description, "Validation failed")
        XCTAssertEqual(error.status, .unprocessableContent)
    }

    func testHTTPError_InternalServerError_HasCorrectProperties() {
        let error = Archaeopteryx.HTTPError.internalServerError()

        XCTAssertEqual(error.code, "internal_server_error")
        XCTAssertEqual(error.description, "Internal server error")
        XCTAssertEqual(error.status, .internalServerError)
    }

    // MARK: - Error Response Format Tests

    func testErrorResponse_EncodesCorrectly() throws {
        let response = ErrorResponse(
            error: "test_error",
            errorDescription: "This is a test error"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(response)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("test_error"))
        XCTAssertTrue(json.contains("This is a test error"))
        XCTAssertTrue(json.contains("error_description"))
    }

    func testErrorResponse_DecodesCorrectly() throws {
        let json = """
        {
            "error": "test_error",
            "error_description": "This is a test error"
        }
        """

        let decoder = JSONDecoder()
        let data = json.data(using: .utf8)!
        let response = try decoder.decode(ErrorResponse.self, from: data)

        XCTAssertEqual(response.error, "test_error")
        XCTAssertEqual(response.errorDescription, "This is a test error")
    }

    // MARK: - Error Classification Tests

    func testErrorClassification_HTTPError_MapsCorrectly() {
        let testCases: [(error: Archaeopteryx.HTTPError, expectedCode: String, expectedStatus: HTTPResponse.Status)] = [
            (Archaeopteryx.HTTPError.badRequest("test"), "invalid_request", .badRequest),
            (Archaeopteryx.HTTPError.unauthorized(), "unauthorized", .unauthorized),
            (Archaeopteryx.HTTPError.forbidden(), "forbidden", .forbidden),
            (Archaeopteryx.HTTPError.notFound("test"), "not_found", .notFound),
            (Archaeopteryx.HTTPError.unprocessableEntity("test"), "unprocessable_entity", .unprocessableContent),
            (Archaeopteryx.HTTPError.internalServerError(), "internal_server_error", .internalServerError),
        ]

        for testCase in testCases {
            XCTAssertEqual(testCase.error.code, testCase.expectedCode)
            XCTAssertEqual(testCase.error.status, testCase.expectedStatus)
        }
    }

    // MARK: - LocalizedError Conformance

    func testHTTPError_ConformsToLocalizedError() {
        let error = HTTPError.badRequest("Test error")

        XCTAssertNotNil(error.errorDescription)
        XCTAssertEqual(error.errorDescription, "Test error")
    }

    // MARK: - Custom Error Tests

    func testHTTPError_CustomCodeAndMessage() {
        let error = Archaeopteryx.HTTPError(
            code: "custom_error",
            description: "This is a custom error",
            status: .badGateway
        )

        XCTAssertEqual(error.code, "custom_error")
        XCTAssertEqual(error.description, "This is a custom error")
        XCTAssertEqual(error.status, .badGateway)
    }
}

// MARK: - Test Helpers

/// ErrorResponse for testing (mirror of private type)
private struct ErrorResponse: Codable {
    let error: String
    let errorDescription: String

    enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
    }
}
