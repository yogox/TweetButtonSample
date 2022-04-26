# TweetButtonSample
SwiftUI Tweet button sample to tweet with image.

## You need
- iOS15
- Twitter depeloper acount that has access level of **Elevated**

## Preview image
### Default View
![defultview](https://user-images.githubusercontent.com/6459717/165109189-08175e61-645e-4bd9-8e58-77876abf36e4.png)

### At editing text
![editingview](https://user-images.githubusercontent.com/6459717/165109217-91493dcd-cb7d-43de-a9af-bc32605edcec.png)

## Usage
1. Fill ConsumerKeys.json in Assets with value of your Twitter App's Consumer Keys
<img width="1026" alt="FillKey" src="https://user-images.githubusercontent.com/6459717/165225216-99dd9e92-864c-4f2c-ac25-aa8f4fb41ecd.png">

2.　Set OAuth1.0a to ON ,App permissions to "Read and write" and "Callback URI/Redirect URL" to any value in your Twitter App's user authentication settings.

3.　Change TwitterClient.swift's properties, oauthCallback and callbackURLScheme suitable for "Callback URI/Redirect URL" set in above.
<img width="1026" alt="Schema" src="https://user-images.githubusercontent.com/6459717/165227805-3c09ce0f-b815-418f-bfe1-f1fa5ba33f0d.png">
