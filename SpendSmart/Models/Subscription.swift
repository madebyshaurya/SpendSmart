//
//  Subscription.swift
//  SpendSmart
//
//  Created by SpendSmart Team on 2025-08-13.
//

import Foundation

struct Subscription: Identifiable, Codable, Equatable {
    enum BillingCycle: String, CaseIterable, Codable {
        case weekly
        case monthly
        case quarterly
        case semiannual
        case annual
        case custom
    }

    var id: UUID
    var user_id: UUID
    var name: String
    var service_name: String
    var logo_url: String?
    var amount: Double
    var currency: String
    var billing_cycle: BillingCycle
    var interval_count: Int? // For custom cycle or multi-month intervals
    var next_renewal_date: Date
    var is_active: Bool
    var is_trial: Bool
    var trial_end_date: Date?
    var notify_before_renewal_days: Int
    var notify_before_trial_end_days: Int
    var notes: String?
    var category: String?
    var payment_method: String?

    enum CodingKeys: String, CodingKey {
        case id
        case user_id
        case name
        case service_name
        case logo_url
        case amount
        case currency
        case billing_cycle
        case interval_count
        case next_renewal_date
        case is_active
        case is_trial
        case trial_end_date
        case notify_before_renewal_days
        case notify_before_trial_end_days
        case notes
        case category
        case payment_method
    }

    init(
        id: UUID = UUID(),
        user_id: UUID,
        name: String,
        service_name: String,
        logo_url: String? = nil,
        amount: Double,
        currency: String,
        billing_cycle: BillingCycle,
        interval_count: Int? = nil,
        next_renewal_date: Date,
        is_active: Bool = true,
        is_trial: Bool = false,
        trial_end_date: Date? = nil,
        notify_before_renewal_days: Int = 3,
        notify_before_trial_end_days: Int = 2,
        notes: String? = nil,
        category: String? = nil,
        payment_method: String? = nil
    ) {
        self.id = id
        self.user_id = user_id
        self.name = name
        self.service_name = service_name
        self.logo_url = logo_url
        self.amount = amount
        self.currency = currency
        self.billing_cycle = billing_cycle
        self.interval_count = interval_count
        self.next_renewal_date = next_renewal_date
        self.is_active = is_active
        self.is_trial = is_trial
        self.trial_end_date = trial_end_date
        self.notify_before_renewal_days = notify_before_renewal_days
        self.notify_before_trial_end_days = notify_before_trial_end_days
        self.notes = notes
        self.category = category
        self.payment_method = payment_method
    }
}


