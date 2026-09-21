//
//  MarkdownDemoUITests.swift
//  MarkdownDemoUITests
//
//  Created by 曹凯 on 2026/5/21.
//

import XCTest

final class MarkdownDemoUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        let app = XCUIApplication()
        app.launch()

        #if os(macOS)
        if !app.staticTexts["Source"].exists {
            app.menuBars.menuBarItems["File"].click()
            app.menuItems["New"].click()
        }
        XCTAssertTrue(app.staticTexts["Source"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Preview"].exists)
        #else
        XCTAssertTrue(app.navigationBars["Markdown 测试案例"].waitForExistence(timeout: 5))
        #endif
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    #if os(macOS)
    @MainActor
    func testEditorModesAndNativeFind() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)"]
        app.launch()
        if !app.textViews["markdown.source"].exists {
            app.typeKey("n", modifierFlags: .command)
        }
        let source = app.textViews["markdown.source"]
        XCTAssertTrue(source.waitForExistence(timeout: 5))
        source.click()
        source.typeKey("a", modifierFlags: .command)
        source.typeText("123 456 123")
        XCTAssertTrue(app.staticTexts["3 words"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["11 characters"].waitForExistence(timeout: 5))

        app.radioButtons["Read"].click()
        XCTAssertFalse(source.exists)
        XCTAssertTrue(app.staticTexts["Preview"].exists)
        app.radioButtons["Edit"].click()
        XCTAssertTrue(source.waitForExistence(timeout: 5))
        XCTAssertEqual(source.value as? String, "123 456 123")
        XCTAssertFalse(app.staticTexts["Preview"].exists)

        source.click()
        source.typeKey("z", modifierFlags: .command)
        XCTAssertNotEqual(source.value as? String, "123 456 123")
        source.typeKey("z", modifierFlags: [.command, .shift])
        XCTAssertEqual(source.value as? String, "123 456 123")
        app.buttons["Replace"].click()
        XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 5))
        let search = app.searchFields.firstMatch
        search.click()
        search.typeKey("a", modifierFlags: .command)
        search.typeText("123")
        let replacement = app.textFields.matching(NSPredicate(format: "placeholderValue == 'Replace'")).firstMatch
        replacement.click()
        replacement.typeKey("a", modifierFlags: .command)
        replacement.typeText("9")
        app.buttons["All"].click()
        XCTAssertTrue(app.staticTexts["7 characters"].waitForExistence(timeout: 5))
        XCTAssertEqual(source.value as? String, "9 456 9")
        app.buttons["Done"].click()

        app.radioButtons["Read"].click()
        app.typeKey("z", modifierFlags: .command)
        XCTAssertTrue(app.staticTexts["11 characters"].waitForExistence(timeout: 5))
        app.typeKey("f", modifierFlags: .command)
        XCTAssertTrue(source.waitForExistence(timeout: 5))
        XCTAssertTrue(app.searchFields.firstMatch.exists)
        XCTAssertEqual(source.value as? String, "123 456 123")
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    #endif
}
