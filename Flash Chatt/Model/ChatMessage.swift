//
//  ChatMessage.swift
//  Flash Chatt
//
//  Created by Aryan Shrivastava on 19/01/22.
//

import Foundation


struct ChatMessage: Identifiable {
    var id: String { documentId }
    
    let documentId: String
    let fromId, toId, text: String
    let timestamp: Date
    
    let selectedImageUrl: String
    
    init(documentId: String, data: [String : Any]) {
        self.documentId = documentId
        fromId = data[FirebaseConstants.fromId] as? String ?? ""
        toId = data[FirebaseConstants.toId] as? String ?? ""
        text = data[FirebaseConstants.text] as? String ?? ""
        timestamp = data[FirebaseConstants.timestamp] as? Date ?? Date()
        selectedImageUrl = data["selectedImageUrl"] as? String ?? ""
    }
}
