//
//  Subscription+BackendAPI.swift
//  SpendSmart
//
//  Created by SpendSmart Team on 2025-08-13.
//

import Foundation

extension Subscription {
    func toDictionary() -> [String: Any] {
        let df = ISO8601DateFormatter()
        var dict: [String: Any] = [
            "id": id.uuidString,
            "user_id": user_id.uuidString,
            "name": name,
            "service_name": service_name,
            "amount": amount,
            "currency": currency,
            "billing_cycle": billing_cycle.rawValue,
            "next_renewal_date": df.string(from: next_renewal_date),
            "is_active": is_active,
            "is_trial": is_trial,
            "notify_before_renewal_days": notify_before_renewal_days,
            "notify_before_trial_end_days": notify_before_trial_end_days
        ]
        if let logo = logo_url { dict["logo_url"] = logo }
        if let interval = interval_count { dict["interval_count"] = interval }
        if let trial = trial_end_date { dict["trial_end_date"] = df.string(from: trial) }
        if let notes = notes { dict["notes"] = notes }
        if let cat = category { dict["category"] = cat }
        if let pm = payment_method { dict["payment_method"] = pm }
        return dict
    }
}


