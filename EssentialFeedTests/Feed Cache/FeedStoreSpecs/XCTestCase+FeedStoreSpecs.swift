//
//  XCTestCase+FeedStoreSpecs.swift
//  EssentialFeedTests
//
//  Created by Hashem Aboonajmi on 8/11/20.
//  Copyright © 2020 Hashem Aboonajmi. All rights reserved.
//

import XCTest
import EssentialFeed

extension FeedStoreSpecs where Self: XCTestCase {
 
    func assertThatRetrieveDeliversEmptyOnEmptyCache(on sut: FeedStore, file: StaticString = #file, line: UInt = #line) {
        expect(sut, toRetrieve: .success(.empty), file: file, line: line)
    }
    
    func assertThatRetrieveHasNoSideEffectsOnEmptyCache(on sut: FeedStore, file: StaticString = #file, line: UInt = #line) {
        expect(sut, toRetrieve: .success(.empty), file: file, line: line)
    }
    
    func assertThatRetrieveDeliversFoundValuesOnNonEmptyCache(on sut: FeedStore, file: StaticString = #file, line: UInt = #line) {
        
        let feed = uniqueImageFeed().local
         let timestamp = Date()

          insert((feed, timestamp), to: sut)

        expect(sut, toRetrieve: .success(.found(feed: feed, timestamp: timestamp)), file: file, line: line)
    }
    
    func assertThatRetrieveHasNoSideEffectsOnNonEmptyCache(on sut: FeedStore, file: StaticString = #file, line: UInt = #line) {
        
        let feed = uniqueImageFeed().local
        let timestamp = Date()
        insert((feed, timestamp), to: sut)
        expect(sut, toRetrieveTwice: .success(.found(feed: feed, timestamp: timestamp)))
    }
    
    func assertThatInsertDeliversNoErrorOnEmptyCache(on sut: FeedStore, file: StaticString = #file, line: UInt = #line) {
        
        let insertionError = insert((uniqueImageFeed().local, Date()), to: sut)
        XCTAssertNil(insertionError, "Expected to insert cache successfully")
    }
    
    func assertThatInsertDeliversNoErrorOnNonEmptyCache(on sut: FeedStore, file: StaticString = #file, line: UInt = #line) {
        insert((uniqueImageFeed().local, Date()), to: sut)
        let insertionError = insert((uniqueImageFeed().local, Date()), to: sut)
        XCTAssertNil(insertionError, "Expected to override cache successfully")
    }
    
    func assertThatInsertOverridesPreviouslyInsertedCacheValues(on sut: FeedStore, file: StaticString = #file, line: UInt = #line) {
        insert((uniqueImageFeed().local, Date()), to: sut)
        let latestFeed = uniqueImageFeed().local
        let latestTimestamp = Date()
        insert((latestFeed, latestTimestamp), to: sut)
        expect(sut, toRetrieve: .success(.found(feed: latestFeed, timestamp: latestTimestamp)))
    }
    
    func assertThatDeleteDeliversNoErrorOnEmptyCache(on sut: FeedStore, file: StaticString = #file, line: UInt = #line) {
        let deletionError = deleteCache(from: sut)
        XCTAssertNil(deletionError, "Expected empty cache deletion to succeed")
    }
    
    func assertThatDeleteHasNoSideEffectsOnEmptyCache(on sut: FeedStore, file: StaticString = #file, line: UInt = #line) {
        deleteCache(from: sut)
        expect(sut, toRetrieve: .success(.empty))
    }
    
    func assertThatDeleteDeliversNoErrorOnNonEmptyCache(on sut: FeedStore, file: StaticString = #file, line: UInt = #line) {
        insert((uniqueImageFeed().local, Date()), to: sut)
        
        let deletionError = deleteCache(from: sut)
        XCTAssertNil(deletionError, "Expected non-empty cache deletion to succeed")
    }
    
    func assertThatDeleteEmptiesPreviouslyInsertedCache(on sut: FeedStore, file: StaticString = #file, line: UInt = #line) {
        insert((uniqueImageFeed().local, Date()), to: sut)
        deleteCache(from: sut)
        
        expect(sut, toRetrieve: .success(.empty))
    }
    
    func assertThatSideEffectsRunSerially(on sut: FeedStore, file: StaticString = #file, line: UInt = #line) {
        var completedOperationsInOrder = [XCTestExpectation]()
        
        let op1 = expectation(description: "Operation 1")
        sut.insert(uniqueImageFeed().local, timestamp: Date()) { _ in
            completedOperationsInOrder.append(op1)
            op1.fulfill()
        }
        
        let op2 = expectation(description: "Operation 2")
        sut.deleteCachedFeed { _ in
            completedOperationsInOrder.append(op2)
            op2.fulfill()
        }
        
        let op3 = expectation(description: "Operation 3")
        sut.insert(uniqueImageFeed().local, timestamp: Date()) { _ in
            completedOperationsInOrder.append(op3)
            op3.fulfill()
        }
        
        waitForExpectations(timeout: 5.0)
        XCTAssertEqual(completedOperationsInOrder, [op1, op2, op3], "Expected side-effects to run seially but operations finished in the wrong order")
    }
    
    @discardableResult
    func insert(_ cache: (feed: [LocalFeedImage], timestamp: Date), to sut: FeedStore) -> Error? {
       
       let exp = expectation(description: "Wait for cache inserion")
       var insertionError: Error?
       sut.insert(cache.feed, timestamp: cache.timestamp){ receivedInsertionError in
           insertionError = receivedInsertionError
           exp.fulfill()
       }
       wait(for: [exp], timeout: 1.0)
       return insertionError
    }
   
    @discardableResult
    func deleteCache(from sut: FeedStore) -> Error? {
       let exp = expectation(description: "Wait for cache deletion")
       var deletionError: Error?
       
       sut.deleteCachedFeed { receivedDeletionError in
           deletionError = receivedDeletionError
           exp.fulfill()
       }
       
       wait(for: [exp], timeout: 1.0)
       return deletionError
    }
    
    func expect(_ sut: FeedStore, toRetrieveTwice expectedResult: FeedStore.RetrievalResult, file: StaticString = #file, line: UInt = #line) {
           expect(sut, toRetrieve: expectedResult, file: file, line: line)
           expect(sut, toRetrieve: expectedResult, file: file, line: line)
       }
       
    func expect(_ sut: FeedStore, toRetrieve expectedResult: FeedStore.RetrievalResult, file: StaticString = #file, line: UInt = #line) {
       let exp = expectation(description: "Wait for cache retrieval")
       
       sut.retrieve{ retrievedResult in
           switch (retrievedResult, expectedResult) {
           case (.success(.empty), .success(.empty)),
                (.failure, .failure):
               break
           case let (.success(.found(feed: expectedFeed, timestamp: expectedTimestamp)), .success(.found(feed: retrievedFeed, timestamp: retrievedTimestamp))):
               XCTAssertEqual(expectedFeed, retrievedFeed, file: file, line: line)
               XCTAssertEqual(expectedTimestamp, retrievedTimestamp, file: file, line: line)
               
           default:
               XCTFail("Expected to retrieve \(expectedResult), got \(retrievedResult) instead", file: file, line: line)
           }
           exp.fulfill()
       }
       wait(for: [exp], timeout: 1.0)
    }
}
