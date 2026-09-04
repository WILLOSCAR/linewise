import Foundation

/// Runs a list of named specifications and reports only what actually passed.
///
/// The count and the printed `PASS:` line are both derived from the
/// specification that just ran, so removing a specification lowers the total
/// instead of leaving a hardcoded number that silently drifts from reality.
///
/// Returns the number of specifications that passed. Throws on the first
/// failure, after printing it, so a red suite exits nonzero.
func runSpecifications(
  _ specifications: [(String, () async throws -> Void)]
) async throws -> Int {
  var passed = 0
  for (name, specification) in specifications {
    do {
      try await specification()
    } catch {
      print("FAIL: \(name) — \(error)")
      throw error
    }
    print("PASS: \(name)")
    passed += 1
  }
  return passed
}
