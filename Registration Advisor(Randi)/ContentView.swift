import SwiftUI
import AVKit// For audio and video
    
    struct ContentView: View {
        @State private var player = AVPlayer()//This gives swiftUI one persistent player instead of recreating it every time body refreshes.AVLPlayer runs the video
        @State private var username = ""
        @State private var password = ""
        @State private var goHome = false//This is used to change views from login to second view
        
        var body: some View
        {    //Bundle.main.url asks the app can you find this file inside my apps resources and give me its location and then return its url.
            NavigationStack
            {
                ZStack()//alignmnet tells SwiftUi where to position child views inside a contianer where there is extra space. .top mkae it go up.
                {
                    VideoPlayer(player: player)// /VideoPlayer displays the video. This UI videplayer is connect tothe state variable player and can perorm re-rendering when player changes
                        .ignoresSafeArea()
                        .allowsHitTesting(false)//Tells swiftUi the video should not receive taps or keyboard focus, than my username and password can receive the interaction instead. Without this line the video background interferes with username and password touchs and wont let me type in them.
                        .padding()
                    
                    Rectangle()
                        .foregroundStyle(.blue)
                        .frame(width: 380,height:310)
                        .offset(x:0,y: 260)
                        .padding()
                    
                    Rectangle()
                        .foregroundStyle(.blue)
                        .frame(width: 380, height: 320)
                        .offset(x:0,y:-240)
                        .padding()
                    
                    VStack(spacing: 30)
                    {
                        Image("Ice")
                            .resizable()//lets it change size
                            .scaledToFit()//makes it fit inside frames.
                            .frame(width:300, height:250)
                        Spacer()
                        TextField("Username", text: $username)
                            .foregroundColor(.black)
                            .background(Color.white.opacity(0.9))
                            .cornerRadius(10)
                            .frame(width: 200)
                            .padding()
                        
                        SecureField("Password", text: $password)
                            .foregroundColor(.black)
                            .background(Color.white.opacity(0.9))
                            .cornerRadius(10)
                            .frame(width: 200)
                            .padding()
                        
                        
                        Button("Login In")
                        {
                            goHome = true
                        }
                        .foregroundColor(.black)
                        .background(Color.red.opacity(0.9))
                        .cornerRadius(100)
                        .offset(x:-5, y: -30)
                        .frame(width: 200)
                        .padding()
                        
                        
                        .navigationDestination(isPresented: $goHome) {//When gohHome becomes true show homevie.
                            //SwiftUi modifier is job is to tell swiftUi when this boolean ebcomes true, navigate to this destination view. isPresented means watch this boolean, when it becomes true show the destination.Ispresentred means is this destination currenly being shown.
                            HomeView()//This creates the destination screen.
                        }
                    }
                }
                .padding()//Provided padding to all of zstack
                .onAppear//runs code when this view appears on the screen
                {
                    //Bundle.mian represent file packaged with your app. .url() asks the app bundle to find a file and reutrn its url
                    guard let url = Bundle.main.url(forResource: "270540_medium", withExtension: "mp4")//Look inside the app bundle for a file named 270540 and give me its location
                    else{//If that file exist store it in url otherwise go to else
                        return//Exit the block because there is no video to be loaded
                    }
                    
                    player.replaceCurrentItem(with: AVPlayerItem(url:url))//replacecurrentitem tells plater to use a new video. AVPlayer creates a playable media item from the file location.
                    player.isMuted = true
                    player.play()//Tells the video to begin. With this line palyback begins automatically.
                }
            }
        }
    }

    
#Preview {
    ContentView()
}
