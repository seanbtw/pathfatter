import XCTest
@testable import PathConverterKit

final class PathConverterKitTests: XCTestCase {

    // MARK: - Windows → macOS (default mappings)

    func testWindowsDriveToMac() {
        let result = PathConverter.convert("C:\\Users\\sean\\Documents\\file.docx")
        XCTAssertEqual(result, "/Volumes/C/Users/sean/Documents/file.docx")
    }

    func testWindowsDriveRoot() {
        let result = PathConverter.convert("D:\\")
        XCTAssertEqual(result, "/Volumes/D")
    }

    func testWindowsUNCtoSMB() {
        let result = PathConverter.convert("\\\\server\\share\\folder")
        XCTAssertEqual(result, "smb://server/share/folder")
    }

    func testWindowsUNCRoot() {
        let result = PathConverter.convert("\\\\server\\share")
        XCTAssertEqual(result, "smb://server/share")
    }

    // MARK: - macOS → Windows (default mappings)

    func testMacVolumesToWindows() {
        let result = PathConverter.convert("/Volumes/C/Users/sean/Documents")
        XCTAssertEqual(result, "C:\\Users\\sean\\Documents")
    }

    func testMacVolumesRoot() {
        let result = PathConverter.convert("/Volumes/D")
        XCTAssertEqual(result, "D:\\")
    }

    func testMacSMBtoUNC() {
        let result = PathConverter.convert("smb://server/share/folder")
        XCTAssertEqual(result, "\\\\server\\share\\folder")
    }

    func testMacSMBRoot() {
        let result = PathConverter.convert("smb://server/share")
        XCTAssertEqual(result, "\\\\server\\share")
    }

    func testMacGenericPathToWindows() {
        let result = PathConverter.convert("/Users/sean/Desktop/file.txt")
        XCTAssertEqual(result, "C:\\Users\\sean\\Desktop\\file.txt")
    }

    // MARK: - Custom drive mappings

    func testCustomDriveMapping() {
        let mappings = [PathMapping(windowsPrefix: "K", macPrefix: "/Volumes/Projects")]
        let result = PathConverter.convert("K:\\Reports\\Q1.pdf", mappings: mappings)
        XCTAssertEqual(result, "/Volumes/Projects/Reports/Q1.pdf")
    }

    func testCustomDriveMappingReverse() {
        let mappings = [PathMapping(windowsPrefix: "K", macPrefix: "/Volumes/Projects")]
        let result = PathConverter.convert("/Volumes/Projects/Reports/Q1.pdf", mappings: mappings)
        XCTAssertEqual(result, "K:\\Reports\\Q1.pdf")
    }

    // MARK: - SharePoint

    func testSharePointURL() {
        let result = PathConverter.isSharePointURL("https://contoso.sharepoint.com/sites/Team/Shared%20Documents/file.docx")
        XCTAssertTrue(result)
    }

    func testNonSharePointURL() {
        let result = PathConverter.isSharePointURL("https://google.com/search")
        XCTAssertFalse(result)
    }

    func testSharePointConversion() {
        // normalizeHomeRoot resolves $HOME, so use an absolute path that won't be remapped
        let localRoot = "/tmp/OneDrive-Team-Test"
        let mappings = [SharePointMapping(sharePointPrefix: "/sites/Team/Shared Documents", localRoot: localRoot)]
        let result = PathConverter.convert("https://contoso.sharepoint.com/sites/Team/Shared Documents/report.pdf", sharePointMappings: mappings)
        XCTAssertEqual(result, "/tmp/OneDrive-Team-Test/report.pdf")
    }

    // MARK: - Edge cases

    func testEmptyInput() {
        let result = PathConverter.convert("")
        XCTAssertEqual(result, "")
    }

    func testWhitespaceInput() {
        let result = PathConverter.convert("   C:\\Temp   ")
        XCTAssertEqual(result, "/Volumes/C/Temp")
    }

    func testIsWindowsPath() {
        XCTAssertTrue(PathConverter.isWindowsPath("C:\\Temp"))
        XCTAssertTrue(PathConverter.isWindowsPath("\\\\server\\share"))
        XCTAssertTrue(PathConverter.isWindowsPath("D:"))
    }

    func testIsNotWindowsPath() {
        XCTAssertFalse(PathConverter.isWindowsPath("/Volumes/C/Temp"))
        XCTAssertFalse(PathConverter.isWindowsPath("smb://server/share"))
        XCTAssertFalse(PathConverter.isWindowsPath("hello world"))
    }

    // MARK: - Normalization

    func testMappingNormalization() {
        let mappings = [PathMapping(windowsPrefix: "c:\\", macPrefix: "/Volumes/C/")]
        let normalized = PathConverter.normalizeMappings(mappings)
        XCTAssertEqual(normalized[0].windowsPrefix, "C")
        XCTAssertEqual(normalized[0].macPrefix, "/Volumes/C")
    }
}