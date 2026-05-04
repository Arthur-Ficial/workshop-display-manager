import SwiftUI

/// Two-column key/value row used in the IDENTITY section.
public struct KVRow: View {
    let key: String
    let value: String
    public init(_ key: String, _ value: String) {
        self.key = key
        self.value = value
    }
    public var body: some View {
        HStack {
            Text(key).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.system(size: 12, weight: .medium))
                .lineLimit(1).truncationMode(.middle)
        }
    }
}
