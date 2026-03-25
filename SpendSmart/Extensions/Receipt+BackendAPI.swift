import Foundation

extension Receipt {
    func toDictionary() throws -> [String: Any] {
        let df = ISO8601DateFormatter()
        var dict: [String: Any] = [
            "id": id.uuidString,
            "user_id": user_id.uuidString,
            "image_urls": image_urls,
            "total_amount": total_amount,
            "store_name": store_name,
            "store_address": store_address,
            "receipt_name": receipt_name,
            "purchase_date": df.string(from: purchase_date),
            "currency": currency,
            "payment_method": payment_method,
            "total_tax": total_tax
        ]
        if let logo = logo_search_term { dict["logo_search_term"] = logo }
        dict["items"] = try items.map { try $0.toDictionary() }
        return dict
    }
    
    static func fromDictionary(_ dict: [String: Any]) throws -> Receipt {
        guard let id = (dict["id"] as? String).flatMap(UUID.init),
              let userId = (dict["user_id"] as? String).flatMap(UUID.init),
              let total = dict["total_amount"] as? Double,
              let store = dict["store_name"] as? String,
              let addr = dict["store_address"] as? String,
              let name = dict["receipt_name"] as? String,
              let dateStr = dict["purchase_date"] as? String,
              let curr = dict["currency"] as? String,
              let pm = dict["payment_method"] as? String,
              let tax = dict["total_tax"] as? Double else {
            throw BackendAPIError.decodingFailed
        }
        
        let df = ISO8601DateFormatter()
        df.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = df.date(from: dateStr) ?? {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
            f.timeZone = TimeZone(secondsFromGMT: 0)
            f.locale = Locale(identifier: "en_US_POSIX")
            return f.date(from: dateStr)
        }() else { throw BackendAPIError.decodingFailed }

        let urls = (dict["image_urls"] as? [String]) ?? (dict["image_url"] as? String).map { [$0] } ?? []
        let items = try (dict["items"] as? [[String: Any]])?.map { try ReceiptItem.fromDictionary($0) } ?? []
        
        return Receipt(id: id, user_id: userId, image_urls: urls, total_amount: total, items: items, store_name: store, store_address: addr, receipt_name: name, purchase_date: date, currency: curr, payment_method: pm, total_tax: tax, logo_search_term: dict["logo_search_term"] as? String)
    }
}

extension ReceiptItem {
    func toDictionary() throws -> [String: Any] {
        var dict: [String: Any] = ["id": id.uuidString, "name": name, "price": price, "category": category, "isDiscount": isDiscount]
        if let op = originalPrice { dict["originalPrice"] = op }
        if let desc = discountDescription { dict["discountDescription"] = desc }
        return dict
    }
    
    static func fromDictionary(_ dict: [String: Any]) throws -> ReceiptItem {
        guard let id = (dict["id"] as? String).flatMap(UUID.init),
              let name = dict["name"] as? String,
              let price = dict["price"] as? Double,
              let cat = dict["category"] as? String else {
            throw BackendAPIError.decodingFailed
        }
        return ReceiptItem(id: id, name: name, price: price, category: cat, originalPrice: dict["originalPrice"] as? Double, discountDescription: dict["discountDescription"] as? String, isDiscount: dict["isDiscount"] as? Bool ?? false)
    }
}
