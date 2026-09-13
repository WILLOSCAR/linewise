import XCTest

final class CoreFlowTests: XCTestCase {
    @MainActor
    func testNoPhotoRecordKeepsFallLocation() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-seedDemo", "-openBuilder"]
        app.launch()
        let noPhoto = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "不拍照")).firstMatch
        XCTAssertTrue(noPhoto.waitForExistence(timeout: 15))
        noPhoto.tap()
        let name = app.textFields["如 蓝色 · 3 号（作为线名）"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("UI Test")
        app.buttons["建好"].tap()
        let record = app.buttons["记这一次"]
        XCTAssertTrue(record.waitForExistence(timeout: 5))
        record.tap()
        let fall = app.textFields["掉在哪（例如：大球、第三个点）"]
        XCTAssertTrue(fall.waitForExistence(timeout: 5))
        fall.tap()
        fall.typeText("third hold")
        app.buttons["保存"].tap()
        XCTAssertTrue(record.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["掉在 third hold"].waitForExistence(timeout: 5))
        record.tap()
        XCTAssertTrue(fall.waitForExistence(timeout: 5))
        XCTAssertEqual(fall.value as? String, "third hold")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "no-photo-record-reopened"
        shot.lifetime = .keepAlways
        add(shot)
    }

    @MainActor
    func testSequenceDragAppendsAndUndoRestores() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-seedDemo", "-openLine", "蓝", "-detailScrollTo", "sequence"]
        app.launch()
        let plan = app.buttons["计划顺序，5 步"]
        XCTAssertTrue(plan.waitForExistence(timeout: 15))
        plan.tap()
        let canvas = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "顺序画布")).firstMatch
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))
        let values = try XCTUnwrap(canvas.value as? String).split(separator: ",").compactMap { Double($0) }
        XCTAssertEqual(values.count, 5)
        XCTAssertEqual(values[0], 5)
        let start = canvas.coordinate(withNormalizedOffset: CGVector(dx: values[1], dy: values[2]))
        let target = canvas.coordinate(withNormalizedOffset: CGVector(dx: values[3], dy: values[4]))
        start.press(forDuration: 0.1, thenDragTo: target)
        XCTAssertTrue(NSPredicate(format: "value BEGINSWITH %@", "6,").evaluate(with: canvas), canvas.debugDescription)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "sequence-after-real-drag"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.buttons["撤销最后一步"].tap()
        XCTAssertTrue(NSPredicate(format: "value BEGINSWITH %@", "5,").evaluate(with: canvas))
        app.buttons["关闭"].tap()
        XCTAssertTrue(plan.waitForExistence(timeout: 5))
    }
}
