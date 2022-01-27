//
//  Flash_ChattApp.swift
//  Flash Chatt
//
//  Created by Aryan Shrivastava on 20/12/21.
//

import SwiftUI
import Firebase

@main
struct Flash_ChattApp: App {
    
    init(){
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
//            LoginView()
            MainMessagesView()
        }
    }
}
