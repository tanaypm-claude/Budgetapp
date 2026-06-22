import Foundation

/// Read-only index of categories/accounts/projects by id, built once per view
/// render from `@Query` results, so rows can resolve names/colors cheaply.
struct Lookups {
    let categories: [UUID: Category]
    let accounts: [UUID: Account]
    let projects: [UUID: Project]

    init(categories: [Category] = [], accounts: [Account] = [], projects: [Project] = []) {
        self.categories = Dictionary(categories.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        self.accounts = Dictionary(accounts.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        self.projects = Dictionary(projects.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    }

    func category(_ id: UUID?) -> Category? { id.flatMap { categories[$0] } }
    func account(_ id: UUID?) -> Account? { id.flatMap { accounts[$0] } }
    func project(_ id: UUID?) -> Project? { id.flatMap { projects[$0] } }

    func categoryName(_ id: UUID?) -> String { category(id)?.name ?? "Uncategorised" }
    func accountName(_ id: UUID?) -> String { account(id)?.name ?? "—" }
}
