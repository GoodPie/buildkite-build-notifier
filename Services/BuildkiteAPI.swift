//
//  BuildkiteAPI.swift
//  BuildkiteNotifier
//
//  Created by Brandyn Britton on 2025-10-20.
//

import Foundation

enum APIError: Error {
    case unauthorized
    case organizationNotFound
    case buildNotFound
    case networkError(Error)
    case invalidResponse
    case decodingError(Error)
    case rateLimited
}

/// Buildkite REST API v2 client
/// Handles authentication and HTTP requests to the Buildkite API
/// Error handling: Throws APIError for all failures (unauthorized, network, decoding, rate limits)
class BuildkiteAPI {
    private let baseURL = "https://api.buildkite.com/v2"
    private var apiToken: String?

    func setToken(_ token: String) {
        self.apiToken = token
    }

    // MARK: - User

    /// Fetch authenticated user information
    /// - Returns: User object with id, name, email
    /// - Throws: APIError.unauthorized if token is missing or invalid
    func fetchUser() async throws -> User {
        guard let token = apiToken else {
            throw APIError.unauthorized
        }

        let url = URL(string: "\(baseURL)/user")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            if httpResponse.statusCode == 401 {
                throw APIError.unauthorized
            }

            if httpResponse.statusCode == 429 {
                throw APIError.rateLimited
            }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(User.self, from: data)
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }

    // MARK: - Builds

    func fetchUserBuilds(orgSlug: String, userId: String, perPage: Int = 10) async throws -> [Build] {
        guard let token = apiToken else {
            throw APIError.unauthorized
        }

        var components = URLComponents(string: "\(baseURL)/organizations/\(orgSlug)/builds")!
        components.queryItems = [
            URLQueryItem(name: "creator", value: userId),
            URLQueryItem(name: "per_page", value: "\(perPage)"),
            URLQueryItem(name: "include_retried_jobs", value: "false")
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            if httpResponse.statusCode == 401 {
                throw APIError.unauthorized
            }

            if httpResponse.statusCode == 404 {
                throw APIError.organizationNotFound
            }

            if httpResponse.statusCode == 429 {
                throw APIError.rateLimited
            }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .iso8601

            let buildResponses = try decoder.decode([BuildResponse].self, from: data)
            return buildResponses.map { $0.toBuild(orgSlug: orgSlug) }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }

    func fetchBuild(org: String, pipeline: String, number: Int) async throws -> Build {
        guard let token = apiToken else {
            throw APIError.unauthorized
        }

        var components = URLComponents(string: "\(baseURL)/organizations/\(org)/pipelines/\(pipeline)/builds/\(number)")!
        components.queryItems = [
            URLQueryItem(name: "include_retried_jobs", value: "false")
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            if httpResponse.statusCode == 401 {
                throw APIError.unauthorized
            }

            if httpResponse.statusCode == 404 {
                throw APIError.buildNotFound
            }

            if httpResponse.statusCode == 429 {
                throw APIError.rateLimited
            }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .iso8601

            let buildResponse = try decoder.decode(BuildResponse.self, from: data)
            return buildResponse.toBuild(orgSlug: org)
        } catch let error as APIError {
            throw error
        } catch let error as DecodingError {
            throw APIError.decodingError(error)
        } catch {
            throw APIError.networkError(error)
        }
    }
}

// MARK: - Response Models

struct User: Codable {
    let id: String
    let name: String?
    let email: String?
}

struct BuildResponse: Codable {
    let id: String
    let number: Int
    let state: BuildState
    let message: String
    let commit: String
    let branch: String
    let createdAt: Date
    let startedAt: Date?
    let finishedAt: Date?
    let webUrl: String
    let pipeline: PipelineResponse
    let jobs: [JobResponse]?

    func toBuild(orgSlug: String) -> Build {
        // Convert jobs to build steps, filtering out jobs without state (wait steps, triggers, etc.)
        let steps = jobs?.enumerated().compactMap { index, job -> BuildStep? in
            guard job.state != nil else { return nil }  // Skip jobs without state
            return job.toStep(order: index)
        }

        return Build(
            id: id,
            buildNumber: number,
            pipelineSlug: pipeline.slug,
            pipelineName: pipeline.name,
            organizationSlug: orgSlug,
            branch: branch,
            commitMessage: message,
            commitSha: commit,
            state: state,
            webUrl: webUrl,
            createdAt: createdAt,
            startedAt: startedAt,
            finishedAt: finishedAt,
            addedManually: false,
            lastNotifiedState: nil,
            steps: steps
        )
    }
}

struct PipelineResponse: Codable {
    let slug: String
    let name: String
}

struct JobResponse: Codable {
    let id: String
    let name: String?
    let state: String?  // Optional: some job types (wait, trigger) don't have state
    let exitStatus: Int?
    let startedAt: Date?
    let finishedAt: Date?

    func toStep(order: Int) -> BuildStep {
        BuildStep(
            id: id,
            name: name ?? "Unnamed Step",
            state: state ?? "pending",  // Default to "pending" if no state
            exitStatus: exitStatus,
            order: order
        )
    }
}
