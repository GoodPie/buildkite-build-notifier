//
//  URLParser.swift
//  BuildkiteNotifier
//
//  Created by Brandyn Britton on 2025-10-20.
//

import Foundation

class URLParser {
    static func parse(_ urlString: String) -> (org: String, pipeline: String, number: Int)? {
        // Regex pattern: https://buildkite.com/{org}/{pipeline}/builds/{number}
        let pattern = #"https://buildkite\.com/([^/]+)/([^/]+)/builds/(\d+)"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: urlString, options: [], range: NSRange(location: 0, length: urlString.utf16.count)) else {
            return nil
        }

        guard match.numberOfRanges == 4,
              let orgRange = Range(match.range(at: 1), in: urlString),
              let pipelineRange = Range(match.range(at: 2), in: urlString),
              let numberRange = Range(match.range(at: 3), in: urlString) else {
            return nil
        }

        let org = String(urlString[orgRange])
        let pipeline = String(urlString[pipelineRange])
        let numberString = String(urlString[numberRange])

        guard let number = Int(numberString) else {
            return nil
        }

        return (org, pipeline, number)
    }
}
