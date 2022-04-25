//
//  ContentView.swift
//  TweetButtonSample
//
//  Created by yogox on 2022/04/22.
//

import SwiftUI
import CoreImage.CIFilterBuiltins
import PartialSheet

enum TweetViewConfirm {
    case tweet
    case signout
    case cancel
}

struct ContentView: View {
    // ツイート用プロパティ
    let twitter: TwitterClient = TwitterClient()
    @State private var image: UIImage?
    @State private var text: String = ""
    @State private var authriozedUser: UserInfo? = nil

    // 表示制御用プロパティ
    @State private var isTweetViewPresent: Bool = false
    @State private var ButtonSelect: TweetViewConfirm = .cancel
    @State private var tweetSemaphore = DispatchSemaphore(value: 0)
    
    let iconLength: CGFloat = 60
    let iPhoneStyle = PSIphoneStyle(
        background: .blur(.ultraThin),
        handleBarStyle: .solid(.secondary),
        cover: .enabled(Color.black.opacity(0.4)),
        cornerRadius: 20
    )
    

    var body: some View {
        
        NavigationView {
            // なぜかGeometryReaderで囲わないと.ignoresSafeArea(.keyboard)が機能しない
            GeometryReader { geometry in
                
                VStack() {
                    Button(action: {
                        self.tweet()
                    }) {
                        Image("Twitter.Icons.square.rounded")
                            .resizable()
                            .scaledToFit()
                            .frame(width: iconLength, height: iconLength)
                    }
                    Text("タップしてツイート")

                // 表示テスト用
                // このボタンから表示したTweetViewを閉じると、待受に使用するセマフォの値がズレます
//                PSButton(
//                    isPresenting: $isTweetViewPresent,
//                    label: {
//                        Text("Display the Partial Sheet")
//                    })
                
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .navigationBarHidden(true)
                .partialSheet(isPresented: $isTweetViewPresent,
                              iPhoneStyle: iPhoneStyle,
                              content: {
                    TweetView(text: $text,
                              image: image,
                              userInfo: authriozedUser,
                              isPresent: $isTweetViewPresent,
                              confirm: $ButtonSelect,
                              semaphore: $tweetSemaphore
                    )
                })
                
            }
            // .ignoresSafeAreaを設定しないと、TweetViewでキーボードが表示された時に下のこの画面も動いてしまう
            .ignoresSafeArea(.keyboard)
        }
        .attachPartialSheetToRoot()
        
    }
    
    func makeTestImage() -> UIImage {
        let rect = CGRect(origin: .zero, size: .init(width: 480, height: 480))
        let filter = CIFilter.textImageGenerator()
        filter.text = "Test Image"
        filter.fontSize = 80
        var ciImage = filter.outputImage!
        ciImage = ciImage.transformed(by: .init(translationX: 45.5, y: 193))
        ciImage = ciImage.composited(over: .white.cropped(to: rect))
        
        let sRGBContext = CIContext(options: nil)
        let cgImage = sRGBContext.createCGImage(ciImage, from: ciImage.extent)
        
        let image = UIImage(cgImage: cgImage!)
        return image
    }
    
    func tweet() {
        DispatchQueue.global(qos: .userInitiated).async {
            // OAuth認証をメインスレッドで実行して待ち受ける
            DispatchQueue.main.async {
                twitter.auth(viewController: UIHostingController(rootView: self))
            }
            twitter.wait()
            
            // 認証失敗でも進んでいくので一旦認証チェック
            if twitter.isAuthorized == false {
                return
            }
            
            // TweetViewに表示するユーザー情報を取得
            authriozedUser = twitter.getUserInfo()
            guard authriozedUser != nil else { return }

            self.ButtonSelect = .cancel
            self.image = makeTestImage()

            // TweetViewをハーフモーダルで表示してボタン押下を待ち受ける
            DispatchQueue.main.async {
                isTweetViewPresent = true
            }
            tweetSemaphore.wait()
            
            // ボタン押下結果によって分岐
            switch ButtonSelect {
            case .tweet:
                twitter.uploadAndTweetWith(image!, text: text)
            case .signout:
                twitter.signOut()
                return
            case .cancel:
                return
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
