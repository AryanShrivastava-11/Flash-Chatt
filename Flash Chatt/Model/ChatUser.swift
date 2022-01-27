//
//  ChatUser.swift
//  Flash Chatt
//
//  Created by Aryan Shrivastava on 14/01/22.
//

import SwiftUI

struct ChatUser: Identifiable{
    var id: String { uid }
    
    let uid, email, profileImageURL: String
    
    init(data: [String : Any]){
         uid = data["uid"] as? String ?? ""
         email = data["email"] as? String ?? ""
         profileImageURL = data["profileImageURL"] as? String ?? ""
    }
}
