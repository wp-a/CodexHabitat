import PetRuntime

enum PetDoctor {
    static func run() -> Int32 {
        do {
            let entries = try PetLibrary(root: PetLibrary.petRoot()).discover()
            let valid = entries.filter { $0.status == .valid }.count
            let invalid = entries.filter {
                if case .invalid = $0.status { return true }
                return false
            }.count
            let duplicates = entries.filter { $0.status == .duplicateID }.count

            print("pets-total: \(entries.count)")
            print("pets-valid: \(valid)")
            print("pets-invalid: \(invalid)")
            print("pets-duplicate: \(duplicates)")
            return 0
        } catch {
            print("pets-total: unavailable")
            print("pets-valid: unavailable")
            print("pets-invalid: unavailable")
            print("pets-duplicate: unavailable")
            return 1
        }
    }
}
