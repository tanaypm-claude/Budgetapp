import XCTest
@testable import Budgetapp

final class DeduplicationTests: XCTestCase {

    private func date(_ iso: String) -> Date { ValueParsing.parseDate(iso)! }

    func testFlagsDuplicateAgainstExisting() {
        let existing: Set<TransactionSignature> = [
            TransactionSignature(date: date("2026-06-01"), amount: Decimal(450), merchant: "Swiggy Bangalore")
        ]
        let parsed = [ParsedTransaction(date: date("2026-06-01"), merchant: "Swiggy Bangalore", amount: Decimal(450))]
        let result = DeduplicationService.flagDuplicates(in: parsed, existing: existing)
        XCTAssertTrue(result[0].isDuplicate)
        XCTAssertFalse(result[0].isSelectedForImport)
    }

    func testFlagsDuplicateWithinSameBatch() {
        let parsed = [
            ParsedTransaction(date: date("2026-06-01"), merchant: "Uber", amount: Decimal(320)),
            ParsedTransaction(date: date("2026-06-01"), merchant: "Uber", amount: Decimal(320))
        ]
        let result = DeduplicationService.flagDuplicates(in: parsed, existing: [])
        XCTAssertFalse(result[0].isDuplicate)
        XCTAssertTrue(result[1].isDuplicate)
    }

    func testDifferentAmountIsNotDuplicate() {
        let existing: Set<TransactionSignature> = [
            TransactionSignature(date: date("2026-06-01"), amount: Decimal(450), merchant: "Swiggy")
        ]
        let parsed = [ParsedTransaction(date: date("2026-06-01"), merchant: "Swiggy", amount: Decimal(451))]
        let result = DeduplicationService.flagDuplicates(in: parsed, existing: existing)
        XCTAssertFalse(result[0].isDuplicate)
    }

    func testDifferentDayIsNotDuplicate() {
        let existing: Set<TransactionSignature> = [
            TransactionSignature(date: date("2026-06-01"), amount: Decimal(450), merchant: "Swiggy")
        ]
        let parsed = [ParsedTransaction(date: date("2026-06-02"), merchant: "Swiggy", amount: Decimal(450))]
        let result = DeduplicationService.flagDuplicates(in: parsed, existing: existing)
        XCTAssertFalse(result[0].isDuplicate)
    }

    func testNormalizationIgnoresTrailingNoise() {
        // Same first tokens, different trailing reference => same signature.
        let a = TransactionSignature(date: date("2026-06-01"), amount: Decimal(450), merchant: "SWIGGY BANGALORE 12345")
        let b = TransactionSignature(date: date("2026-06-01"), amount: Decimal(450), merchant: "swiggy bangalore 99999")
        XCTAssertEqual(a, b)
    }

    func testSignatureMagnitudeIgnoresSign() {
        XCTAssertEqual(TransactionSignature.amountKey(Decimal(-450)), TransactionSignature.amountKey(Decimal(450)))
    }

    // MARK: Account-aware fingerprint

    func testSameTxnDifferentAccountsNotDuplicate() {
        let accountA = UUID()
        let accountB = UUID()
        let existing: Set<TransactionSignature> = [
            TransactionSignature(date: date("2026-06-01"), amount: Decimal(450), merchant: "Swiggy", accountId: accountA)
        ]
        let parsed = [
            ParsedTransaction(date: date("2026-06-01"), merchant: "Swiggy", amount: Decimal(450), resolvedAccountId: accountB)
        ]
        let result = DeduplicationService.flagDuplicates(in: parsed, existing: existing)
        XCTAssertFalse(result[0].isDuplicate, "Same merchant/date/amount on a different account is not a duplicate")
    }

    func testSameTxnSameAccountIsDuplicate() {
        let account = UUID()
        let existing: Set<TransactionSignature> = [
            TransactionSignature(date: date("2026-06-01"), amount: Decimal(450), merchant: "Swiggy", accountId: account)
        ]
        let parsed = [
            ParsedTransaction(date: date("2026-06-01"), merchant: "Swiggy", amount: Decimal(450), resolvedAccountId: account)
        ]
        let result = DeduplicationService.flagDuplicates(in: parsed, existing: existing)
        XCTAssertTrue(result[0].isDuplicate)
    }

    func testSignaturesFromTransactionsCarryAccount() {
        let accountA = UUID()
        let txn = Transaction(date: date("2026-06-01"), merchant: "Swiggy", amount: Decimal(450),
                              type: .expense, accountId: accountA)
        let set = DeduplicationService.signatures(for: [txn])
        XCTAssertTrue(set.contains(TransactionSignature(date: date("2026-06-01"), amount: Decimal(450), merchant: "Swiggy", accountId: accountA)))
        XCTAssertFalse(set.contains(TransactionSignature(date: date("2026-06-01"), amount: Decimal(450), merchant: "Swiggy", accountId: UUID())))
    }
}
