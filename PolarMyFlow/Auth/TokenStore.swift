protocol TokenStore {
    func save(_ token: AuthToken) throws
    func load() throws -> AuthToken?
    func delete() throws
}
