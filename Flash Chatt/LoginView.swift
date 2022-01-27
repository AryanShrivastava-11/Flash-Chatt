//
//  ContentView.swift
//  Flash Chatt
//
//  Created by Aryan Shrivastava on 20/12/21.
//

import SwiftUI
import Firebase
import FirebaseFirestore

struct LoginView: View {
    
    let didCompleteLoginProcess: () -> ()
    
    @State var isLoginMode: Bool = false
    @State var email = ""
    @State var password = ""
    @State var shouldShowImagePicker = false
    @State var image: UIImage?
    
    var body: some View {
        NavigationView{
            ScrollView{
                VStack(spacing: 16){
                    Picker(selection: $isLoginMode) {
                        Text("Login")
                            .tag(true)
                        Text("Create Account")
                            .tag(false)
                    } label: {
                        Text("Picker for CreateAccout & Login")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    if !isLoginMode{
                        
                        VStack {
                            Button {
                                shouldShowImagePicker.toggle()
                            } label: {
                                if let image = image {
                                    Image(uiImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 150, height: 150)
                                        .cornerRadius(80)
                                }else{
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 64))
                                        .padding()
                                        .foregroundColor(Color.primary)
                                }
                            }
                        }
                        .overlay(RoundedRectangle(cornerRadius: 80)
                                    .stroke(lineWidth: 5))
                        
                    }
                    
                    Group{
                        ZStack(alignment: .leading){
                            TextField("", text: $email)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                            if email.isEmpty{
                                Text("Email")
                                    .font(.system(size: 15, weight: .light,design: .rounded))
                                    .foregroundColor(.gray)
                                    .opacity(0.8)
                            }
                        }
                        ZStack(alignment: .leading){
                            SecureField("", text: $password)
                            if password.isEmpty{
                                Text("Password")
                                    .font(.system(size: 15, weight: .light,design: .rounded))
                                    .foregroundColor(.gray)
                                    .opacity(0.8)
                            }
                        }
                            
                            
                        
                    }
                    .padding(12)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    Button {
                        handleAction()
                    } label: {
                        HStack {
                            Spacer()
                            Text(isLoginMode ? "Log in" : "Create Account")
                                .foregroundColor(.white)
                                .padding(.vertical,10)
                                .font(.system(size: 12, weight: .bold))
                            Spacer()
                        }
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    
                    Text(loginStatusMessage)
                        .foregroundColor(.red)
                }
                .padding()
            }
            .navigationTitle(isLoginMode ? "Log in":"Create Account")
            .background(
                 Color(.init(white: 0, alpha: 0.05))
                            .ignoresSafeArea()
            )
            
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .fullScreenCover(isPresented: $shouldShowImagePicker, onDismiss: nil) {
            ImagePicker(image: $image)
                .ignoresSafeArea()
        }
    }
    
    private func handleAction(){
        if isLoginMode{
//            print("Just do the login")
            loginUser()
        }else{
            createNewAccount()
//            print("New user here")
        }
    }
    
    @State var loginStatusMessage = ""
    
    private func createNewAccount(){
        if image == nil {
            loginStatusMessage = "You must select an Avatar image."
            return
        }
        
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            
            if let err = error{
                loginStatusMessage = "Failed to create user: \(err)"
                return
            }
            
            loginStatusMessage = "Successfully created user: \(result?.user.uid ?? "UID not available")"
            
            persistImageToStorage()
        }
    }
    
     private func persistImageToStorage(){
         guard let uid = Auth.auth().currentUser?.uid else { return }
         let ref = Storage.storage().reference(withPath: uid)
         guard let imageData = image?.jpegData(compressionQuality: 0.5) else { return }
         
         ref.putData(imageData, metadata: nil) { metaData, error in
             if let err = error{
                 loginStatusMessage = "Failed to push image to Storage: \(err)"
                 return
             }
             ref.downloadURL { url, error in
                 if let err = error {
                     loginStatusMessage = "Failed to retrieve downloadURL: \(err)"
                     return
                 }
                 
                 loginStatusMessage = "Successfully stored image with url: \(url)"
                 print(url?.absoluteString)
                 
                 guard let url = url else { return }
                 storeUserInformation(imageProfileUrl:  url)
             }
             
         }
    }
    
    private func storeUserInformation(imageProfileUrl: URL){
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let userData = ["email" : email , "uid" : uid , "profileImageURL": imageProfileUrl.absoluteString]
        Firestore.firestore().collection("users").document(uid).setData(userData) { error in
            if let err = error{
                print(err)
                loginStatusMessage = "\(err)"
                return
            }
            print("success")
            didCompleteLoginProcess()
        }
    }
    
    private func loginUser(){
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            if let err = error{
                loginStatusMessage = "Error while login: \(err)"
                return
            }
            
            loginStatusMessage = "User login successful: \(result?.user.uid ?? "UID not available")"
            
            didCompleteLoginProcess()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView(didCompleteLoginProcess: {
            
        })
//            .preferredColorScheme(.dark)
    }
}
 
