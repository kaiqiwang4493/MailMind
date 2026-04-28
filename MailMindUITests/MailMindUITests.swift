import XCTest

final class MailMindUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSubmitButtonStartsDisabled() throws {
        let app = launchApp()

        let submitButton = app.buttons["submitAnalysisButton"]
        XCTAssertTrue(submitButton.waitForExistence(timeout: 5))
        XCTAssertFalse(submitButton.isEnabled)
    }

    @MainActor
    func testSampleMailEnablesSubmitAndShowsResult() throws {
        let app = launchApp()

        createSampleMailAnalysis(in: app)

        XCTAssertTrue(app.staticTexts["邮件摘要"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["添加待办"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testTodoSwipeActionsMatchCompletionState() throws {
        let app = launchApp()

        createSampleMailAnalysis(in: app)
        addSuggestedTodo(in: app)
        app.tabBars.buttons["待办"].tap()

        let pendingTodo = app.staticTexts["核对账单金额并完成付款"]
        XCTAssertTrue(pendingTodo.waitForExistence(timeout: 5))
        pendingTodo.swipeLeft()
        XCTAssertTrue(app.buttons["完成"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["删除"].waitForExistence(timeout: 3))

        app.buttons["完成"].tap()
        XCTAssertTrue(app.alerts["确认完成？"].waitForExistence(timeout: 3))
        app.alerts["确认完成？"].buttons["确认完成"].tap()

        XCTAssertTrue(app.staticTexts["没有待完成事项"].waitForExistence(timeout: 5))
        app.buttons["已完成"].tap()

        let completedTodo = app.staticTexts["核对账单金额并完成付款"]
        XCTAssertTrue(completedTodo.waitForExistence(timeout: 5))
        completedTodo.swipeLeft()
        XCTAssertTrue(app.buttons["删除"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["完成"].exists)
    }

    @MainActor
    func testSuggestedTodoCanBeAddedAndRemovedFromAnalysisResult() throws {
        let app = launchApp()

        createSampleMailAnalysis(in: app)
        addSuggestedTodo(in: app)
        XCTAssertTrue(app.buttons["移除待办"].waitForExistence(timeout: 5))

        app.tabBars.buttons["待办"].tap()
        XCTAssertTrue(app.staticTexts["核对账单金额并完成付款"].waitForExistence(timeout: 5))

        app.tabBars.buttons["上传"].tap()
        app.buttons["移除待办"].tap()
        XCTAssertTrue(app.buttons["添加待办"].waitForExistence(timeout: 5))

        app.tabBars.buttons["待办"].tap()
        XCTAssertTrue(app.staticTexts["没有待完成事项"].waitForExistence(timeout: 5))
    }

    @discardableResult
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingResetStore"]
        app.launch()
        return app
    }

    private func createSampleMailAnalysis(in app: XCUIApplication) {
        app.buttons["sampleMailButton"].tap()
        let submitButton = app.buttons["submitAnalysisButton"]
        XCTAssertTrue(submitButton.waitForExistence(timeout: 5))
        XCTAssertTrue(submitButton.waitForEnabled(timeout: 5))
        submitButton.tap()
    }

    private func addSuggestedTodo(in app: XCUIApplication) {
        let addButton = app.buttons["添加待办"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}

private extension XCUIElement {
    func waitForEnabled(timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "isEnabled == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
}
