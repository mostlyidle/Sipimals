import SwiftUI

struct PrivacyPolicyView: View {
    private var policy: AttributedString {
        guard let url = Bundle.main.url(forResource: "privacy-policy", withExtension: "md"),
              let markdown = try? String(contentsOf: url, encoding: .utf8),
              let attributed = try? AttributedString(markdown: markdown) else {
            return AttributedString("Privacy policy unavailable.")
        }
        return attributed
    }

    var body: some View {
        ScrollView {
            Text(policy)
                .frame(maxWidth: 520, alignment: .leading)
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(SipTheme.background)
        .foregroundStyle(SipTheme.ink)
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
        .textSelection(.enabled)
    }
}
