import Foundation
import Testing
import Logging
import Hummingbird
@testable import Archaeopteryx

@Suite struct ErrorHandlingMiddlewareTests {
    var logger: Logger!
    var middleware: ErrorHandlingMiddleware<BasicRequestContext>!

    init() async {
       logger = Logger(label: "test")
        logger.logLevel = .critical // Suppress logs during tests
        middleware = ErrorHandlingMiddleware(logger: logger)
    }

    // MARK: - Basic Tests

    @Test func ErrorHandlingMiddleware_CanBeCreated() {
        #expect(middleware != nil)
    }

    // MARK: - HTTPError Tests

    @Test func HTTPError_BadRequest_HasCorrectProperties() {
        let error = Archaeopteryx.HTTPError.badRequest("Invalid parameter")

        #expect(error.code == "invalid_request")
        #expect(error.description == "Invalid parameter")
        #expect(error.status == .badRequest)
    }

    @Test func HTTPError_Unauthorized_HasCorrectProperties() {
        let error = Archaeopteryx.HTTPError.unauthorized()

        #expect(error.code == "unauthorized")
        #expect(error.description == "Authentication required")
        #expect(error.status == .unauthorized)
    }

    @Test func HTTPError_Forbidden_HasCorrectProperties() {
        let error = Archaeopteryx.HTTPError.forbidden()

        #expect(error.code == "forbidden")
        #expect(error.description == "Access denied")
        #expect(error.status == .forbidden)
    }

    @Test func HTTPError_NotFound_HasCorrectProperties() {
        let error = Archaeopteryx.HTTPError.notFound("User not found")

        #expect(error.code == "not_found")
        #expect(error.description == "User not found")
        #expect(error.status == .notFound)
    }

    @Test func HTTPError_UnprocessableEntity_HasCorrectProperties() {
        let error = Archaeopteryx.HTTPError.unprocessableEntity("Validation failed")

        #expect(error.code == "unprocessable_entity")
        #expect(error.description == "Validation failed")
        #expect(error.status == .unprocessableContent)
    }

    @Test func HTTPError_InternalServerError_HasCorrectProperties() {
        let error = Archaeopteryx.HTTPError.internalServerError()

        #expect(error.code == "internal_server_error")
        #expect(error.description == "Internal server error")
        #expect(error.status == .internalServerError)
    }

    // MARK: - Error Response Format Tests

    @Test func ErrorResponse_EncodesCorrectly() throws {
        let response = ErrorResponse(
            error: "test_error",
            errorDescription: "This is a test error"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(response)
        let json = String(data: data, encoding: .utf8)!

        #expect(json.contains("test_error"))
        #expect(json.contains("This is a test error"))
        #expect(json.contains("error_description"))
    }

    @Test func ErrorResponse_DecodesCorrectly() throws {
        let json = """
        {
            "error": "test_error",
            "error_description": "This is a test error"
        }
        """

        let decoder = JSONDecoder()
        let data = json.data(using: .utf8)!
        let response = try decoder.decode(ErrorResponse.self, from: data)

        #expect(response.error == "test_error")
        #expect(response.errorDescription == "This is a test error")
    }

    // MARK: - Error Classification Tests

    @Test func ErrorClassification_HTTPError_MapsCorrectly() {
        let testCases: [(error: Archaeopteryx.HTTPError, expectedCode: String, expectedStatus: HTTPResponse.Status)] = [
            (Archaeopteryx.HTTPError.badRequest("test"), "invalid_request", .badRequest),
            (Archaeopteryx.HTTPError.unauthorized(), "unauthorized", .unauthorized),
            (Archaeopteryx.HTTPError.forbidden(), "forbidden", .forbidden),
            (Archaeopteryx.HTTPError.notFound("test"), "not_found", .notFound),
            (Archaeopteryx.HTTPError.unprocessableEntity("test"), "unprocessable_entity", .unprocessableContent),
            (Archaeopteryx.HTTPError.internalServerError(), "internal_server_error", .internalServerError),
        ]

        for testCase in testCases {
            #expect(testCase.error.code == testCase.expectedCode)
            #expect(testCase.error.status == testCase.expectedStatus)
        }
    }

    // MARK: - LocalizedError Conformance

    @Test func HTTPError_ConformsToLocalizedError() {
        let error = HTTPError.badRequest("Test error")

        #expect(error.errorDescription != nil)
        #expect(error.errorDescription == "Test error")
    }

    // MARK: - Custom Error Tests

    @Test func HTTPError_CustomCodeAndMessage() {
        let error = Archaeopteryx.HTTPError(
            code: "custom_error",
            description: "This is a custom error",
            status: .badGateway
        )

        #expect(error.code == "custom_error")
        #expect(error.description == "This is a custom error")
        #expect(error.status == .badGateway)
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

