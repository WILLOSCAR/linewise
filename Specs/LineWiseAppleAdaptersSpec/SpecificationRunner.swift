import Foundation

/// Runs a list of named specifications and reports only what actually passed.
///
/// The previous runners printed a fixed block of `PASS:` lines and returned a
/// hardcoded count, so a specification could be removed from its sub-suite and
/// the suite would still print its `PASS:` line and the same total. That makes a
/// green suite unfalsifiable, which is worse than no suite at all. Here the
/// printed line and the reported count are both derived from the specification
/// that just ran, so deleting one reduces the total and skipping one is visible.
///
/// Returns the number of specifications that passed. Throws on the first
/// failure, after printing the failure, so a red suite exits nonzero.
///
/// Isolated to the main actor because several of these specifications drive
/// `@MainActor` view models, and the list therefore cannot cross an isolation
/// boundary under Swift 6 strict concurrency.
@MainActor
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
