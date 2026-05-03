import XCTest

final class MailMindUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSubmitButtonStartsDisabled() throws {
        let app = launchApp()
        enterGuestMode(in: app)

        let submitButton = app.buttons["submitAnalysisButton"]
        XCTAssertTrue(submitButton.waitForExistence(timeout: 5))
        XCTAssertFalse(submitButton.isEnabled)
    }

    @MainActor
    func testLaunchShowsLoginChoicesBeforeTabs() throws {
        let app = launchApp()

        XCTAssertTrue(app.buttons["guestModeButton"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["appleSignInButton"].exists)
        XCTAssertTrue(app.buttons["googleSignInButton"].exists)
        XCTAssertFalse(app.tabBars.buttons["上传"].exists)
    }

    @MainActor
    func testGuestModeEntersMainTabs() throws {
        let app = launchApp()

        enterGuestMode(in: app)

        XCTAssertTrue(app.tabBars.buttons["上传"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["submitAnalysisButton"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testDarkSystemAppearanceKeepsReadableLightUI() throws {
        let app = launchApp(arguments: ["-uiTestingResetStore", "-AppleInterfaceStyle", "Dark"])

        enterGuestMode(in: app)
        app.tabBars.buttons["待办"].tap()

        XCTAssertTrue(app.staticTexts["待办事项"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["待完成"].exists)
        XCTAssertTrue(app.buttons["已完成"].exists)
    }

    @MainActor
    func testSampleMailEnablesSubmitAndShowsResult() throws {
        let app = launchApp()
        enterGuestMode(in: app)

        createSampleMailAnalysis(in: app)

        XCTAssertTrue(app.staticTexts["邮件摘要"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["添加待办"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testTodoSwipeActionsMatchCompletionState() throws {
        let app = launchApp()
        enterGuestMode(in: app)

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
        enterGuestMode(in: app)

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

    @MainActor
    func testGuestExitClearsGuestData() throws {
        let app = launchApp()
        enterGuestMode(in: app)
        createSampleMailAnalysis(in: app)

        app.buttons["账号"].tap()
        XCTAssertTrue(app.staticTexts["访客"].waitForExistence(timeout: 5))
        app.buttons["退出访客并清除数据"].tap()
        XCTAssertTrue(app.alerts["清除访客数据？"].waitForExistence(timeout: 5))
        app.alerts["清除访客数据？"].buttons["清除并退出"].tap()

        XCTAssertTrue(app.buttons["guestModeButton"].waitForExistence(timeout: 5))
        enterGuestMode(in: app)
        app.tabBars.buttons["历史"].tap()
        XCTAssertTrue(app.staticTexts["还没有历史记录"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testMockGoogleSignInEntersMainTabs() throws {
        let app = launchApp(arguments: ["-uiTestingResetStore", "-uiTestingMockAuth"])

        app.buttons["googleSignInButton"].tap()

        XCTAssertTrue(app.tabBars.buttons["上传"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testFaceIDUnlockRestoresExistingMockSession() throws {
        let app = launchApp(arguments: [
            "-uiTestingResetStore",
            "-uiTestingExistingAuth",
            "-uiTestingFaceIDEnabled",
            "-uiTestingFaceIDSuccess"
        ])

        XCTAssertTrue(app.tabBars.buttons["上传"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testFaceIDUnlockFailureStaysOnUnlockPageForRetry() throws {
        let app = launchApp(arguments: [
            "-uiTestingResetStore",
            "-uiTestingExistingAuth",
            "-uiTestingFaceIDEnabled",
            "-uiTestingFaceIDFailure"
        ])

        XCTAssertTrue(app.alerts["提示"].waitForExistence(timeout: 5))
        app.alerts["提示"].buttons["知道了"].tap()
        XCTAssertTrue(app.buttons["faceIDUnlockButton"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["signInAgainButton"].exists)

        app.buttons["faceIDUnlockButton"].tap()
        XCTAssertTrue(app.alerts["提示"].waitForExistence(timeout: 5))
        app.alerts["提示"].buttons["知道了"].tap()
        app.buttons["signInAgainButton"].tap()
        XCTAssertTrue(app.buttons["guestModeButton"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["appleSignInButton"].exists)
        XCTAssertTrue(app.buttons["googleSignInButton"].exists)
    }

    @MainActor
    func testSignedInUserCanSignOutFromAnalysisResult() throws {
        let app = launchApp(arguments: ["-uiTestingResetStore", "-uiTestingMockAuth"])

        app.buttons["googleSignInButton"].tap()
        XCTAssertTrue(app.tabBars.buttons["上传"].waitForExistence(timeout: 5))

        createSampleMailAnalysis(in: app)
        app.buttons["账号"].tap()
        XCTAssertTrue(app.buttons["退出登录"].waitForExistence(timeout: 5))
        app.buttons["退出登录"].tap()

        XCTAssertTrue(app.buttons["guestModeButton"].waitForExistence(timeout: 5))
    }

    @discardableResult
    private func launchApp(arguments: [String] = ["-uiTestingResetStore"]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
        return app
    }

    private func enterGuestMode(in app: XCUIApplication) {
        let guestButton = app.buttons["guestModeButton"]
        XCTAssertTrue(guestButton.waitForExistence(timeout: 5))
        guestButton.tap()
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
