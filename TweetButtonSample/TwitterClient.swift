//
//  TwitterClient.swift
//  TweetButtonSample
//
//  Created by yogox on 2022/04/22.
//

import AuthenticationServices
import TwitterAPIKit

struct ConsumerKeys: Decodable {
    var APIKey: String
    var APIKeySecret: String
}

struct UserInfo: Decodable {
    let data: Data
    
    struct Data: Decodable {
        let id: String
        let username: String
        let name: String
        let profile_image_url: String
    }
    
    // 表示用に@のついたユーザー名
    static let unPrefix: String = "@"
    func displayUsername() -> String {
        return Self.unPrefix + self.data.username
    }
}

class AuthPresentationContextProver: NSObject, ASWebAuthenticationPresentationContextProviding {
    private weak var viewController: UIViewController!
    
    init(viewController: UIViewController) {
        self.viewController = viewController
        super.init()
    }
    
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        ASPresentationAnchor()
    }
}

class TwitterClient {
    let consumerKey: String
    let consumerSecret: String
    let oauthTokenUserDefaultsKey = "oauthTokenUserDefaultsKey"
    let oauthTokenSecretUserDefaultsKey = "oauthTokenSecretUserDefaultsKey"
    let oauthCallback = "tweetbuttonsample://"
    let callbackURLScheme = "tweetbuttonsample"
    
    var session: ASWebAuthenticationSession?
    var presentationContextProvider: AuthPresentationContextProver?
    
    lazy var client: TwitterAPIKit =  .init(
        .oauth(
            consumerKey: consumerKey,
            consumerSecret: consumerSecret,
            oauthToken: UserDefaults.standard.string(forKey: oauthTokenUserDefaultsKey),
            oauthTokenSecret: UserDefaults.standard.string(forKey: oauthTokenSecretUserDefaultsKey)
        )
    )
    
    var isAuthorized: Bool {
        if case .oauth(consumerKey: _, consumerSecret: _, oauthToken: .some, oauthTokenSecret: .some) = client.apiAuth {
            return true
        } else {
            return false
        }
    }
    
    private let semaphore = DispatchSemaphore(value: 0)

    init() {
        let asset = NSDataAsset(name: "ConsumerKeys")
        let keys = try! JSONDecoder().decode(ConsumerKeys.self, from: asset!.data)
        consumerKey = keys.APIKey
        consumerSecret = keys.APIKeySecret
        //    consumerKey = "<JSONを読むかわりにハードコーディングでもよい（非推奨）>"
        //    consumerSecret = "<JSONを読むかわりにハードコーディングでもよい（非推奨）"
    }
    
    func auth(viewController: UIViewController) {
        if isAuthorized {
            // セマフォ解放
            self.semaphore.signal()
            return
        }
        
        client = .init(.oauth(
            consumerKey: consumerKey,
            consumerSecret: consumerSecret,
            oauthToken: UserDefaults.standard.string(forKey: oauthTokenUserDefaultsKey),
            oauthTokenSecret: UserDefaults.standard.string(forKey: oauthTokenSecretUserDefaultsKey)
        ))
        
        // API v2がMEDIAをサポートするまでは、v1.1を使用するためにAOuth1で認証する必要がある
        client.auth.oauth10a.postOAuthRequestToken(.init(oauthCallback: oauthCallback))
            .responseObject { [self] response in
                do {
                    let success = try response.result.get()
                    let url = client.auth.oauth10a.makeOAuthAuthorizeURL(.init(oauthToken: success.oauthToken))!
                    self.session = .init(url: url, callbackURLScheme: callbackURLScheme) { url, error in
                        
                        // url is "sharesample://?oauth_token=<string>&oauth_verifier=<string>"
                        guard let url = url else {
                            if let error = error {
                                print("Error:", error)
                            }
                            // セマフォ解放
                            self.semaphore.signal()
                            return
                        }
                        print("URL:", url)
                        
                        let component = URLComponents(url: url, resolvingAgainstBaseURL: false)
                        guard let oauthToken = component?.queryItems?.first(where: { $0.name == "oauth_token"} )?.value,
                              let oauthVerifier = component?.queryItems?.first(where: { $0.name == "oauth_verifier"})?.value else {
                            print("Invalid URL")
                            // セマフォ解放
                            self.semaphore.signal()
                            return
                        }
                        self.client.auth.oauth10a.postOAuthAccessToken(.init(oauthToken: oauthToken, oauthVerifier: oauthVerifier))
                            .responseObject { response in
                                
                                guard let success = response.success else {
                                    print("Error", String(describing: response.error))
                                    // セマフォ解放
                                    self.semaphore.signal()
                                    return
                                }
                                
                                let oauthToken = success.oauthToken
                                let oauthTokenSecret = success.oauthTokenSecret
                                UserDefaults.standard.set(oauthToken, forKey: self.oauthTokenUserDefaultsKey)
                                UserDefaults.standard.set(oauthTokenSecret, forKey: self.oauthTokenSecretUserDefaultsKey)
                                
                                self.client = .init(
                                    consumerKey: self.consumerKey,
                                    consumerSecret: self.consumerSecret,
                                    oauthToken: oauthToken,
                                    oauthTokenSecret: oauthTokenSecret
                                )
                                
                                // セマフォ解放
                                self.semaphore.signal()
                                
                            }
                    }
                    presentationContextProvider = .init(viewController: viewController)
                    session?.presentationContextProvider = presentationContextProvider
                    session?.prefersEphemeralWebBrowserSession = true
                    session?.start()
                    
                } catch let e {
                    print("Error", e)
                    // セマフォ解放
                    self.semaphore.signal()
                    return
                }
            }
    }
    
    func getUserInfo() -> UserInfo? {
        var userInfo: UserInfo?
        client.v2.user.getMe(.init(expansions: .none, tweetFields: .none, userFields: [.profileImageUrl])).responseObject { response in
            if response.isError != true {
                let data = response.data
                do {
                    userInfo = try JSONDecoder().decode(UserInfo.self, from: data!)
                    print(userInfo!)
                    
                    // セマフォ解放
                    self.semaphore.signal()
                } catch {
                    print(error)
                    userInfo = nil
                    
                    // セマフォ解放
                    self.semaphore.signal()
                }
            } else {
                print("Error", String(describing: response.error))
                userInfo = nil
                
                // セマフォ解放
                self.semaphore.signal()
            }
        }
        
        // レスポンス待受
        self.semaphore.wait()
        return userInfo
    }
    
    func uploadAndTweetWith(_ image: UIImage, text: String = "") {
        let imageData = image.pngData()
        
        // v1.1を使用するためには、Elevated申請が必要（無料だけど簡単な審査あり）
        client.v1.media.uploadMedia(.init(media: imageData!, mediaType: "image/png.", filename: "")) { [self] response in
            if response.isError != true {
                let mediaID = response.success! as String
                print(mediaID)
                let media = PostTweetsRequestV2.Media(mediaIDs: [mediaID])
                
                client.v2.tweet.postTweet(.init(
                    media: media,
                    text: text
                ))
                .responseObject { response in
                    print(response.prettyString)
                }
            } else {
                print("Error", String(describing: response.error))
            }
        }
    }
    
    func signOut() {
        UserDefaults.standard.removeObject(forKey: oauthTokenUserDefaultsKey)
        UserDefaults.standard.removeObject(forKey: oauthTokenSecretUserDefaultsKey)
        
        client = .init(
            .oauth(
                consumerKey: consumerKey,
                consumerSecret: consumerSecret,
                oauthToken: nil,
                oauthTokenSecret: nil
            )
        )
    }

    func wait() {
        semaphore.wait()
    }
}

