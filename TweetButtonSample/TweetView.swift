//
//  TweetView.swift
//  TweetButtonSample
//
//  Created by yogox on 2022/04/22.
//

import SwiftUI
import TwitterText

extension Configuration {
    static func configuration(fromDataAsset name: String) -> Configuration {
        let asset = NSDataAsset(name: name)
        let jsonString = String(data: asset!.data, encoding: .utf8)!
        return configuration(from: jsonString)!
    }
}

struct TweetView: View {
    @Binding var text: String
    let image: UIImage?
    let userInfo: UserInfo?

    @Binding var isPresent: Bool
    @Binding var confirm: TweetViewConfirm
    @Binding var semaphore: DispatchSemaphore
    
    @State private var tweetLength: Int = 0
    @State private var isValidTweet: Bool = false
    @FocusState private var focus:Bool
    
    // 実機だとdefaultParserがクラッシュするので使えない
    //    let parser = Parser.defaultParser
    // アセットカタログにv3.jsonを追加して拡張メソッドを読み込む
    let parser = Parser(with: .configuration(fromDataAsset: "v3"))
    
    // ツイート初期文字列（実質はlet扱いだがTextEditorに渡すために修飾子を変更している）
    @State var initialText = "THIS IS TEST TWEET"
    let iconLength: CGFloat = 50
    let imageLength: CGFloat = 280
    let editorMinHeight: CGFloat = 54.5
    let editorMaxHeight: CGFloat = 150
    let cornerRadius:CGFloat = 12
    
    let tweetButtonTitle: String = "この画像と文章でツイートする"
    let signoutButtonTitle: String = "%@からサインアウトする"
    let unPlaceHolder: String = "このユーザー"
    let cancelButtonTitle: String = "ツイートをやめる"
    
    
    func checkTweetCount() {
        let result = parser.parseTweet(text: text)
        tweetLength = result.weightedLength
        isValidTweet = result.isValid
    }
    
    func closeView(_ select: TweetViewConfirm) {
        confirm = select
        isPresent = false
    }
    
    var body: some View {
        VStack() {
            HStack(alignment: .top) {
                Spacer()
                
                AsyncImage(url: URL(string: userInfo?.data.profile_image_url ?? "")) { image in
                    image.resizable()
                } placeholder: {
                    Color.primary
                }
                .clipShape(Circle())
                .frame(width: iconLength, height: iconLength)
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    if let image = image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .cornerRadius(cornerRadius)
                            .frame(width: focus ? imageLength * 0.4 : imageLength)
                            .animation(.easeOut(duration: 0.2), value: focus)
                    }
                    
                    VStack(alignment: .trailing) {
                        // PartialSheet上でToolbarItemGroup(placement: .keyboard)を表示するためにはNavigationViewで囲む必要がある
                        NavigationView{
                            TextEditor(text: $text)
                                .foregroundColor(.black)
                                .focused($focus)
                                .toolbar {
                                    ToolbarItemGroup(placement: .keyboard) {
                                        Spacer()
                                        
                                        Button(action: {
                                            focus = false
                                        }) {
                                            Image(systemName: "keyboard.chevron.compact.down")
                                        }
                                    }
                                }
                                .onChange(of: text) { _ in
                                    checkTweetCount()
                                }
                                .background(
                                    EditorPlaceHolderAndBackground()
                                )
                            // PartialSheet上でNavigationViewを使用すると中の表示がおかしくなるので対策にBarを消す
                                .navigationBarHidden(true)
                        }
                        .frame(height: focus ? editorMaxHeight : editorMinHeight)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                        .animation(.easeOut(duration: 0.2), value: focus)
                        
                        TweetLengthPer()
                    }
                }
                .frame(width: imageLength)
                
                Spacer()
            }
            
            VStack(alignment: .center, spacing: 12.5) {
                CustomDivider()
                Button(action: { closeView(.tweet) }) {
                    Text(tweetButtonTitle)
                        .bold()
                }
                .disabled(isValidTweet ? false : true)
                CustomDivider()
                Button(action: { closeView(.signout) }) {
                    Text(String(format: signoutButtonTitle, userInfo?.displayUsername() ?? unPlaceHolder))
                        .lineLimit(1)
                    // W×Ω15文字(UITabBar)を表示しきれるくらいの倍率
                        .minimumScaleFactor(0.75)
                    // 詰めて表示できるなら詰める
                        .allowsTightening(true)
                    // 一応表示しきれなかったら中略
                        .truncationMode(.middle)
                        .foregroundColor(.red)
                }
                CustomDivider()
                Button(action: { closeView(.cancel) }) {
                    Text(cancelButtonTitle)
                }
                CustomDivider()
            }
        }
        .padding(.vertical, focus ? 0 : nil)
//        .animation(.linear, value: focus)
        .onAppear() {
            // TextEditorを角丸表示するため＆プレースホルダーを表示するために背景を透明する
            UITextView.appearance().backgroundColor = .clear
            text = initialText
            checkTweetCount()
        }
        .onDisappear() {
            UITextView.appearance().backgroundColor = nil
            semaphore.signal()
        }
    }
    
    // TextEditorの背景を透明にしたうえで、下にPlaceholder用Editorと角丸四角形を配置する
    func EditorPlaceHolderAndBackground() -> some View {
        return ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(isValidTweet ? .clear : .red, lineWidth: 3)
                .background(RoundedRectangle(cornerRadius: cornerRadius).fill(.white))
            
            TextEditor(text: $initialText)
                .foregroundColor(.gray)
                .opacity(tweetLength > 0 ? 0.0 : 1.0)
         }
    }
    
    func TweetLengthPer() -> some View {
        return Text("\(tweetLength)/\(parser.maxWeightedTweetLength())")
            .foregroundColor(isValidTweet ? .accentColor : .red)
            .kerning(-2)
            .font(.system(.body, design: .monospaced))
    }
    
    func CustomDivider() -> some View {
        return Divider()
            .background(.secondary)
    }
}
