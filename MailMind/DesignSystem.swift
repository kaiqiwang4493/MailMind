import SwiftUI

enum MailMindTheme {
    static let background = Color(red: 0.97, green: 0.97, blue: 0.94)
    static let surface = Color.white
    static let secondarySurface = Color(red: 0.92, green: 0.94, blue: 0.90)
    static let primary = Color(red: 0.29, green: 0.48, blue: 0.40)
    static let primarySoft = Color(red: 0.82, green: 0.89, blue: 0.84)
    static let text = Color(red: 0.12, green: 0.16, blue: 0.14)
    static let mutedText = Color(red: 0.40, green: 0.45, blue: 0.42)
    static let urgent = Color(red: 0.72, green: 0.24, blue: 0.18)
}

struct SectionPanel<Content: View>: View {
    var title: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let title {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(MailMindTheme.text)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(MailMindTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
    }
}

struct CategoryBadge: View {
    var category: MailCategory

    var body: some View {
        Text(category.displayName)
            .font(.headline)
            .foregroundStyle(MailMindTheme.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(MailMindTheme.primarySoft)
            .clipShape(Capsule())
    }
}

extension Date {
    var mailMindShortDate: String {
        formatted(.dateTime.month(.defaultDigits).day().year())
    }
}
