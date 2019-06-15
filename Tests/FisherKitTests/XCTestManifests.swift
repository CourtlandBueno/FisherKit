import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(FisherKitTests.allTests),
        testCase(FisherKitManagerTests.allTests),
        testCase(DataProviderTests.allTests),
        testCase(StorageExpirationTests.allTests),
        testCase(MemoryStorageTests.allTests),
        testCase(DiskStorageTests.allTests),
        testCase(ImageDrawingTests.allTests),
        testCase(ProcessorTests.allTests),
    ]
}
#endif
