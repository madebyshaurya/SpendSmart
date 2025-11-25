import SwiftUI

struct LogoPreview: View {
    var systemFallback: String = "building.2"
    var image: UIImage?
    var title: String
    var tint: Color = .blue

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.gray.opacity(0.2))
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                Image(systemName: systemFallback)
                    .foregroundColor(.gray)
            }
        }
        .frame(width: 40, height: 40)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(0.25), lineWidth: 1)
        )
        .overlay(
            Group {
                if image == nil {
                    Text(String(title.prefix(1)).uppercased())
                        .font(.instrumentSans(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        )
    }
}


