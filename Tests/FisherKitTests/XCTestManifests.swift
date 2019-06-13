import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(FisherKitTests.allTests),
        testCase(FisherKitManagerTests.allTests),
        testCase(DataProviderTests.allTests),
        testCase(DiskStorageTests.allTests),
        testCase(ImageDrawingTests.allTests),
        testCase(MemoryStorageTests.allTests),
        testCase(ProcessorTests.allTests),
        testCase(StorageExpirationTests.allTests),
    ]
}
#endif
