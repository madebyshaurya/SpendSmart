import Foundation

extension Subscription.BillingCycle: CustomStringConvertible {
    public var description: String {
        switch self {
        case .semiannual:
            return "Semiannual"
        default:
            return rawValue.capitalized
        }
    }
}


