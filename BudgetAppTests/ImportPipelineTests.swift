import SwiftData
import UIKit
import XCTest
@testable import BudgetApp

final class ImportPipelineTests: XCTestCase {
    func testPreparedDraftsSendUncertainRowsToReviewQueue() {
        let draft = DraftTransaction(
            date: Date(),
            merchant: "Unknown Merchant",
            amount: 999,
            type: .expense,
            source: .pdfImport,
            confidence: 0.55
        )

        let prepared = ImportPipeline.preparedDrafts([draft], rules: [], existingTransactions: [])

        XCTAssertEqual(prepared.count, 1)
        XCTAssertFalse(prepared[0].isReviewed)
        XCTAssertEqual(prepared[0].needsReviewReason, "Category needed")
    }

    func testPreparedDraftsReviewRowsMatchedByRule() {
        let categoryId = UUID()
        let rule = ImportRule(
            name: "Rent",
            matchField: .description,
            matchType: .contains,
            matchValue: "rent",
            categoryId: categoryId,
            priority: 1
        )
        let draft = DraftTransaction(
            date: Date(),
            merchant: "Bank Transfer",
            narration: "monthly rent",
            amount: 60000,
            type: .expense,
            source: .csvImport,
            confidence: 0.9
        )

        let prepared = ImportPipeline.preparedDrafts([draft], rules: [rule], existingTransactions: [])

        XCTAssertEqual(prepared[0].categoryId, categoryId)
        XCTAssertTrue(prepared[0].isReviewed)
    }

    func testImportedTransactionLeavesReviewQueueAfterCategoryAssignment() throws {
        let container = BudgetAppSchema.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let category = BudgetCategory(name: "Food", symbol: "fork.knife", colorHex: "#D84A2B", monthlyBudget: 5000, sortOrder: 0)
        context.insert(category)

        let draft = DraftTransaction(
            date: Date(),
            merchant: "Swiggy",
            amount: 450,
            type: .expense,
            source: .csvImport,
            isReviewed: false,
            confidence: 0.65
        )

        try ImportPipeline.save(
            drafts: [draft],
            filename: "sample.csv",
            fileType: .csv,
            modelContext: context,
            skipDuplicates: false
        )

        var transactions = try context.fetch(FetchDescriptor<BudgetTransaction>())
        XCTAssertEqual(transactions.filter { !$0.isReviewed }.count, 1)

        transactions[0].categoryId = category.id
        transactions[0].isReviewed = true
        transactions[0].touch()
        try context.save()

        transactions = try context.fetch(FetchDescriptor<BudgetTransaction>())
        XCTAssertTrue(transactions.filter { !$0.isReviewed }.isEmpty)
    }

    func testImportPersistsProjectAssignment() throws {
        let container = BudgetAppSchema.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let category = BudgetCategory(name: "Supplies", symbol: "shippingbox", colorHex: "#750609", monthlyBudget: 3000, sortOrder: 0)
        let project = Project(name: "Studio Build", colorHex: "#750609", monthlyBudget: 10000)
        context.insert(category)
        context.insert(project)

        let draft = DraftTransaction(
            date: Date(),
            merchant: "Hardware Store",
            amount: 1500,
            type: .expense,
            categoryId: category.id,
            projectId: project.id,
            source: .csvImport,
            isReviewed: true,
            confidence: 0.95
        )

        try ImportPipeline.save(
            drafts: [draft],
            filename: "project.csv",
            fileType: .csv,
            modelContext: context,
            skipDuplicates: false
        )

        let transactions = try context.fetch(FetchDescriptor<BudgetTransaction>())
        XCTAssertEqual(transactions.first?.projectId, project.id)
    }

    func testBackupRoundTripEncodeDecodeAndImport() throws {
        let container = BudgetAppSchema.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let category = BudgetCategory(name: "Income", symbol: "arrow.down.circle", colorHex: "#2E7D5B", monthlyBudget: 0, sortOrder: 0)
        let account = BudgetAccount(name: "Primary", type: .bank, openingBalance: 1000.25, currentBalance: 1000.25)
        let project = Project(name: "Apartment", colorHex: "#750609", monthlyBudget: 50000)
        let transaction = BudgetTransaction(
            date: Date(),
            merchant: "Salary",
            amount: 12345.67,
            type: .income,
            categoryId: category.id,
            accountId: account.id,
            projectId: project.id
        )
        let backup = BackupService.makeBackup(
            transactions: [transaction],
            categories: [category],
            accounts: [account],
            recurringPayments: [],
            importBatches: [],
            importRules: [],
            projects: [project]
        )

        let data = try BackupService.encode(backup)
        let decoded = try BackupService.decode(data: data)
        try BackupService.importBackup(decoded, into: context, replaceExisting: true)

        let importedTransactions = try context.fetch(FetchDescriptor<BudgetTransaction>())
        let importedAccounts = try context.fetch(FetchDescriptor<BudgetAccount>())
        let importedProjects = try context.fetch(FetchDescriptor<Project>())
        XCTAssertEqual(importedTransactions.count, 1)
        XCTAssertEqual(importedTransactions[0].amount, Decimal(string: "12345.67")!)
        XCTAssertEqual(importedAccounts[0].openingBalance, Decimal(string: "1000.25")!)
        XCTAssertEqual(importedProjects[0].monthlyBudget, Decimal(50000))
    }

    func testDummyPDFImportCanCreateOverBudgetCategoryWithoutErrors() throws {
        let container = BudgetAppSchema.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let category = BudgetCategory(name: "Food", symbol: "fork.knife", colorHex: "#750609", monthlyBudget: 0, sortOrder: 0)
        context.insert(category)

        let pdfURL = try makeDummyStatementPDF()
        let text = try PDFStatementParser.extractText(from: pdfURL)
        let parsed = try PDFStatementParser.parse(text: text)
        var drafts = PDFStatementParser.drafts(from: parsed, defaultAccountId: nil)
        XCTAssertEqual(drafts.count, 1)
        drafts[0].categoryId = category.id
        drafts[0].isReviewed = true

        try ImportPipeline.save(
            drafts: drafts,
            filename: "dummy-over-budget.pdf",
            fileType: .pdf,
            modelContext: context,
            skipDuplicates: false
        )

        let transactions = try context.fetch(FetchDescriptor<BudgetTransaction>())
        category.monthlyBudget = 1000
        try context.save()

        let rows = BudgetMath.categoryRows(transactions: transactions, categories: [category])
        XCTAssertEqual(transactions.count, 1)
        XCTAssertEqual(transactions[0].amount, Decimal(2500))
        XCTAssertTrue(rows[0].isOverBudget)
        XCTAssertEqual(rows[0].remaining, Decimal(-1500))
    }

    private func makeDummyStatementPDF() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("dummy-over-budget-\(UUID().uuidString).pdf")
        let text = """
        Account Statement
        Date Description Debit Credit Balance
        01/06/2026 Test Grocery Store 2500.00 0.00 97500.00
        End of statement
        """
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842))
        try renderer.writePDF(to: url) { context in
            context.beginPage()
            text.draw(
                in: CGRect(x: 48, y: 48, width: 500, height: 220),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 14),
                    .foregroundColor: UIColor.black
                ]
            )
        }
        return url
    }
}
