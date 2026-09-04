import Foundation
import LineWiseAppleAdapters
import LineWiseDomain

enum AppleAdapterSpecFailure: Error {
  case expected(String)
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
  guard condition() else { throw AppleAdapterSpecFailure.expected(message) }
}

@main
struct LineWiseAppleAdaptersSpecRunner {
  @MainActor
  static func main() async throws {
    var specifications: [(String, () async throws -> Void)] = [
      ("no HealthKit does not block the manual visit", noHealthKitDoesNotBlockTheManualVisit),
      (
        "in-memory transport confirms durable modes deterministically",
        inMemoryTransportConfirmsDurableModes
      ),
      (
        "DeviceEventEnvelope crosses the payload bridge losslessly",
        envelopeCrossesThePayloadBridgeLosslessly
      ),
    ]
    specifications += deviceSyncServiceSpecifications()
    specifications += durableDeviceTransportSpecifications()
    specifications += persistentBootstrapSpecifications()
    specifications += appleRuntimeSpecifications()
    specifications += experienceSurfaceSpecifications()
    specifications += learningExperienceSurfaceSpecifications()
    specifications += routeMediaLibrarySpecifications()

    let passed = try await runSpecifications(specifications)
    print("LineWiseAppleAdaptersSpec: \(passed) passed")
  }
}

private func noHealthKitDoesNotBlockTheManualVisit() async throws {
  let recorder = NoHealthKitWorkoutRecorder()
  let capability = await recorder.capabilityState()
  try expect(
    capability == .unavailable,
    "expected the no-HealthKit path to be explicit"
  )
  try await recorder.start(at: Date(timeIntervalSince1970: 1))
  try await recorder.stop(at: Date(timeIntervalSince1970: 2))
}

private func inMemoryTransportConfirmsDurableModes() async throws {
  let transport = InMemoryDevicePayloadTransport()
  await transport.activate()
  let first = try await transport.send(Data("first".utf8), mode: .reliableBackground)
  let second = try await transport.send(Data("second".utf8), mode: .immediateIfReachable)
  let payloads = await transport.receivedPayloads()
  try expect(
    first.acceptedLocally && second.acceptedLocally,
    "expected the in-memory fake to confirm both durable modes"
  )
  try expect(
    payloads == [Data("first".utf8), Data("second".utf8)],
    "expected transport order to remain stable"
  )
}

private func envelopeCrossesThePayloadBridgeLosslessly() async throws {
  let bridge = DeviceEnvelopeBridge(transport: InMemoryDevicePayloadTransport())
  let envelope = DeviceEventEnvelope(
    originDeviceID: DeviceID("watch"),
    sequence: 1,
    command: .startVisit(
      actionID: ActionID("action-bridge-start"),
      visitID: GymVisitID("visit-bridge-start"),
      occurredAt: Instant(millisecondsSince1970: 1_000),
      source: .watch
    )
  )
  let bridgeReceipt = try await bridge.send(envelope, mode: .reliableBackground)
  let receivedEnvelopes = try await bridge.receivedEnvelopes()
  try expect(bridgeReceipt.acceptedLocally, "expected envelope to enqueue")
  try expect(
    receivedEnvelopes == [envelope],
    "expected a lossless DeviceEventEnvelope round trip"
  )
}
