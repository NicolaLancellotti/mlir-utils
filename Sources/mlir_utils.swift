import ArgumentParser
import Foundation

//MARK: - Commands

@main
struct MLIRUtils: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "MLIR Utils",
    subcommands: [
      CreateDialect.self,
      RenameDialect.self,
    ])
}

struct CreateDialect: ParsableCommand {
  static let configuration = CommandConfiguration(commandName: "create-dialect",
                                                  abstract: "Create a new dialect.")
  
  @Argument(help: "The name of the new dialect.")
  var dialectName: String
  
  @Argument(help: "The path of the LLVM project.", transform: { URL(filePath: $0) })
  var llvmPath: URL
  
  @Argument(help: "The path where to save the new dialect.", transform: { URL(filePath: $0) })
  var dialectPath: URL
  
  func run() throws {
    try createDialect(dialectName, at: dialectPath, llvmPath: llvmPath)
  }
}

struct RenameDialect: ParsableCommand {
  static let configuration = CommandConfiguration(commandName: "rename-dialect",
                                                  abstract: "Rename a dialect.")
  
  @Argument(help: "The current name of the dialect.")
  var dialectName: String
  
  @Argument(help: "The new name of the dialect.")
  var newDialectName: String
  
  @Argument(help: "The path of the dialect.", transform: { URL(filePath: $0) })
  var dialectPath: URL
  
  func run() throws {
    try renameDialect(dialectName, to: newDialectName, at: dialectPath)
  }
}

//MARK: - Actions

func createDialect(_ dialectName: String, at dialectPath: URL, llvmPath: URL) throws {
  let standalonePath = llvmPath.appending(path: "mlir/examples/standalone")
  let dialectPath = dialectPath.appending(path: dialectName.lowercased())
  
  do {
    try FileManager.default.copyItem(at: standalonePath, to: dialectPath)
  } catch {
    fputs("The dialect cannot be created at the specified path\n", stderr)
    return
  }
  
  try renameDialect("Standalone", to: dialectName, at: dialectPath)
}

func renameDialect(_ dialectName: String, to newDialectName: String, at dialectPath: URL) throws {
  let substitutions = [
    (dialectName, newDialectName),
    (dialectName.lowercased(), newDialectName.lowercased()),
    (dialectName.uppercased(), newDialectName.uppercased()),
  ]
  try replaceRecursively(at: dialectPath, substitutions: substitutions)
}

//MARK: - Common

typealias Substitutions = [(target: String, replacement: String)]

func replaceRecursively(at path: URL,
                        substitutions: Substitutions) throws {
  var paths = [path]
  while !paths.isEmpty {
    let currentURLs = paths
    paths = []
    for var path in currentURLs {
      path = try replaceFile(at: path, substitutions: substitutions)
      switch path.isDirectory {
      case true: paths.append(contentsOf: try path.contentsOfDirectory)
      case false: try replaceContentofFile(at: path, substitutions: substitutions)
      }
    }
  }
}

func replaceFile(at path: URL,
                 substitutions: Substitutions) throws -> URL {
  var newPath = path
  for (target, replacement) in substitutions {
    let lastPathComponent = newPath.lastPathComponent
    if lastPathComponent.contains(target) {
      let newURL = newPath.deletingLastPathComponent()
        .appending(path: lastPathComponent.replacingOccurrences(of: target, with: replacement))
      try FileManager.default.moveItem(at: newPath, to: newURL)
      newPath = newURL
    }
  }
  return newPath
}

func replaceContentofFile(at path: URL,
                          substitutions: Substitutions) throws {
  guard var fileContents = try? String(contentsOf: path, encoding: .utf8) else {
    return
  }
  for (target, replacement) in substitutions {
    fileContents.replace(target, with: replacement)
  }
  
  switch fixHeader(fileContents) {
  case .unchanged:
    break
  case .changed(let newContents):
    fileContents = newContents
  case .error:
    fputs("Header too long: \(path.relativePath)\n", stderr)
  }
  
  try fileContents.write(to: path, atomically: true, encoding: .utf8)
}

enum HeaderResult {
  case unchanged
  case changed(String)
  case error
}

func fixHeader(_ fileContents: String) -> HeaderResult {
  guard fileContents.starts(with: "//===-") else { return .unchanged }
  
  let line = fileContents.prefix { $0 != "\n" }
  let diff = 80 - line.count
  guard diff != 0 else { return .unchanged }
  
  var fileContents = fileContents
  
  var s = ""
  for _ in 0 ..< abs(diff) {
    s += "-"
  }
  
  if diff > 0 {
    s += "--"
    let newLine = line.replacing("--", with: s, maxReplacements: 1)
    fileContents.replace(line, with: newLine, maxReplacements: 1)
    return .changed(fileContents)
  } else if line.contains(s) {
    let newLine = line.replacing(s, with: "", maxReplacements: 1)
    fileContents.replace(line, with: newLine, maxReplacements: 1)
    return .changed(fileContents)
  } else {
    return .error
  }
}

//MARK: - Foundation Extension

extension URL {
  var isDirectory: Bool {
    (try? resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
  }
  
  var contentsOfDirectory: [URL] {
    get throws {
      try FileManager.default.contentsOfDirectory(at: self,
                                                  includingPropertiesForKeys: nil)
    }
  }
}
