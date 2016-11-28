//
//  CodeGenerator.swift
//  Eject
//
//  Created by Brian King on 10/18/16.
//  Copyright © 2016 Brian King. All rights reserved.
//

import Foundation

public protocol CodeGenerator {

    /// A set of all identifiers that are dependent on this generator.
    var dependentIdentifiers: Set<String> { get }

    /// Return a line of code, or nil if nothing should be done.
    func generateCode(in document: XIBDocument) throws -> String?

}

extension CodeGenerator {
    var dependentIdentifiers: Set<String> {
        return []
    }
}

public enum CodeGeneratorPhase {
    case initialization
    case configuration
    case dependentConfiguration
    case subviews
    case constraints

    var comment: String {
        switch self {
        case .initialization:
            return "// Create Views"
        case .configuration:
            return "" // Configuration without dependencies -- doesn't really warrent a comment.
        case .dependentConfiguration:
            return "// Remaining Configuration"
        case .subviews:
            return "// Assemble View Hierarchy"
        case .constraints:
            return "// Configure Constraints"
        }
    }
}

extension XIBDocument {

    public func generateCode(disableComments: Bool = false) throws -> [String] {
        var generatedCode: [String] = []

        if !disableComments { generatedCode.append(CodeGeneratorPhase.initialization.comment) }

        // Cluster the declaration with the configuration that is isolated (ie no external references)
        for reference in references {
            generatedCode.append(contentsOf: try reference.generateDeclaration(in: self))
        }

        // Add all of the remaining phases
        for phase: CodeGeneratorPhase in [.subviews, .constraints, .dependentConfiguration] {
            generatedCode.append(contentsOf: try generateCode(for: phase, disableComments: disableComments))
        }

        // Trim trailing empty lines
        if generatedCode.last == "" {
            generatedCode.removeLast()
        }
        return generatedCode
    }

    /// Generate code for the specified phase. The code is generated in the reverse order of objects that were
    /// added so the top level object configuration is last. This is usually how I like to do things.
    func generateCode(for phase: CodeGeneratorPhase, disableComments: Bool) throws -> [String] {
        var lines: [String] = []
        for reference in references.reversed() {
            lines.append(contentsOf: try reference.generateCode(for: phase, in: self))
        }
        if lines.count > 0 {
            if !disableComments { lines.insert(phase.comment, at: 0) }
            lines.append("")
        }
        return lines
    }
}

extension Reference {

    /// Generate the declaration of the object, along with any configuration that is isolated from any external dependencies.
    func generateDeclaration(in document: XIBDocument) throws -> [String] {
        var generatedCode: [String] = []
        var lines = try generateCode(for: .initialization, in: document)
        lines.append(contentsOf: try generateCode(for: .configuration, in: document))
        if lines.count > 0 { generatedCode.append(contentsOf: lines) }
        if lines.count > 1 { generatedCode.append("") }
        return generatedCode
    }

    func generateCode(for phase: CodeGeneratorPhase, in document: XIBDocument) throws -> [String] {
        return try statements
            .filter { $0.phase == phase }
            .map { try $0.generator.generateCode(in: document) }
            .flatMap { $0 }
    }
}
