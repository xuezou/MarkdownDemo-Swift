import Foundation

// 检查 Bundle 中的文件
if let resourcePath = Bundle.main.resourcePath {
    print("Resource Path: \(resourcePath)")
    
    let fm = FileManager.default
    if let items = try? fm.contentsOfDirectory(atPath: resourcePath) {
        print("Root items:")
        for item in items {
            print("  - \(item)")
        }
    }
    
    let testCasesPath = (resourcePath as NSString).appendingPathComponent("TestCases")
    print("\nTestCases exists: \(fm.fileExists(atPath: testCasesPath))")
    
    if fm.fileExists(atPath: testCasesPath) {
        if let subdirs = try? fm.contentsOfDirectory(atPath: testCasesPath) {
            print("TestCases subdirs:")
            for subdir in subdirs {
                print("  - \(subdir)")
            }
        }
    }
}
